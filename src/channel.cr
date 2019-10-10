require "fiber"
require "crystal/spin_lock"

# A `Channel` enables concurrent communication between fibers.
#
# They allow communicating data between fibers without sharing memory and without having to worry about locks, semaphores or other special structures.
#
# ```
# channel = Channel(Int32).new
#
# spawn do
#   channel.send(0)
#   channel.send(1)
# end
#
# channel.receive # => 0
# channel.receive # => 1
# ```
#
# NOTE: Althought a `Channel(Nil)` or any other nilable types like `Channel(Int32?)` are valid
# they are discouraged since from certain methods or constructs it receiving a `nil` as data
# will be indistinguishable from a closed channel.
#
class Channel(T)
  @lock = Crystal::SpinLock.new
  @queue : Deque(T)?

  record NotReady
  record UseDefault

  module SelectAction(S)
    abstract def execute : S | NotReady | UseDefault
    abstract def wait(context : SelectContext(S))
    abstract def wait_result_impl(context : SelectContext(S))
    abstract def unwait
    abstract def result : S
    abstract def lock_object_id
    abstract def lock
    abstract def unlock
    abstract def available? : Bool

    def create_context_and_wait(state_ptr)
      context = SelectContext.new(state_ptr, self)
      self.wait(context)
      context
    end

    # wait_result overload allow implementors to define
    # wait_result_impl with the right type and Channel.select_impl
    # to allow dispatching over unions that will not happen
    def wait_result(context : SelectContext)
      raise "BUG: Unexpected call to #{typeof(self)}#wait_result(context : #{typeof(context)})"
    end

    def wait_result(context : SelectContext(S))
      wait_result_impl(context)
    end

    # Implementor that returns `Channel::UseDefault` in `#execute`
    # must redefine `#default_result`
    def default_result
      raise "unreachable"
    end
  end

  enum SelectState
    None   = 0
    Active = 1
    Done   = 2
  end

  private class SelectContext(S)
    @state : Pointer(Atomic(SelectState))
    property action : SelectAction(S)
    @activated = false

    def initialize(@state, @action : SelectAction(S))
    end

    def activated?
      @activated
    end

    def try_trigger : Bool
      _, succeed = @state.value.compare_and_set(SelectState::Active, SelectState::Done)
      if succeed
        @activated = true
      end
      succeed
    end
  end

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  enum DeliveryState
    None
    Delivered
    Closed
  end

  private record Sender(T), fiber : Fiber, value : T, state_ptr : DeliveryState*, select_context : SelectContext(Nil)?
  private record Receiver(T), fiber : Fiber, value_ptr : T*, state_ptr : DeliveryState*, select_context : SelectContext(T)?

  def initialize(@capacity = 0)
    @closed = false
    @senders = Deque(Sender(T)).new
    @receivers = Deque(Receiver(T)).new
    if capacity > 0
      @queue = Deque(T).new(capacity)
    end
  end

  def close
    @lock.sync do
      @closed = true

      @senders.each do |sender|
        sender.state_ptr.value = DeliveryState::Closed
        sender.select_context.try &.try_trigger
        sender.fiber.enqueue
      end

      @receivers.each do |receiver|
        receiver.state_ptr.value = DeliveryState::Closed
        receiver.select_context.try &.try_trigger
        receiver.fiber.enqueue
      end

      @senders.clear
      @receivers.clear
    end
    nil
  end

  def closed?
    @closed
  end

  def send(value : T)
    @lock.sync do
      raise_if_closed

      send_internal(value) do
        state = DeliveryState::None
        @senders << Sender(T).new(Fiber.current, value, pointerof(state), select_context: nil)
        @lock.unsync do
          Crystal::Scheduler.reschedule
        end

        case state
        when DeliveryState::Delivered
          # ignore
        when DeliveryState::Closed
          raise ClosedError.new
        else
          raise "BUG: Fiber was awaken without channel delivery state set"
        end
      end

      self
    end
  end

  protected def send_internal(value : T)
    if receiver = dequeue_receiver
      receiver.value_ptr.value = value
      receiver.state_ptr.value = DeliveryState::Delivered
      receiver.fiber.enqueue
    elsif (queue = @queue) && queue.size < @capacity
      queue << value
    else
      yield
    end
  end

  # Receives a value from the channel.
  # If there is a value waiting, it is returned immediately. Otherwise, this method blocks until a value is sent to the channel.
  #
  # Raises `ClosedError` if the channel is closed or closes while waiting for receive.
  #
  # ```
  # channel = Channel(Int32).new
  # channel.send(1)
  # channel.receive # => 1
  # ```
  def receive
    receive_impl { raise ClosedError.new }
  end

  # Receives a value from the channel.
  # If there is a value waiting, it is returned immediately. Otherwise, this method blocks until a value is sent to the channel.
  #
  # Returns `nil` if the channel is closed or closes while waiting for receive.
  def receive?
    receive_impl { return nil }
  end

  def receive_impl
    @lock.sync do
      receive_internal do
        yield if @closed

        value = uninitialized T
        state = DeliveryState::None
        @receivers << Receiver(T).new(Fiber.current, pointerof(value), pointerof(state), select_context: nil)
        @lock.unsync do
          Crystal::Scheduler.reschedule
        end

        case state
        when DeliveryState::Delivered
          value
        when DeliveryState::Closed
          yield
        else
          raise "BUG: Fiber was awaken without channel delivery state set"
        end
      end
    end
  end

  def receive_internal
    if (queue = @queue) && !queue.empty?
      deque_value = queue.shift
      if sender = dequeue_sender
        sender.state_ptr.value = DeliveryState::Delivered
        sender.fiber.enqueue
        queue << sender.value
      end
      deque_value
    elsif sender = dequeue_sender
      sender.state_ptr.value = DeliveryState::Delivered
      sender.fiber.enqueue
      sender.value
    else
      yield
    end
  end

  private def dequeue_receiver
    while receiver = @receivers.shift?
      if (select_context = receiver.select_context) && !select_context.try_trigger
        next
      end

      break
    end

    receiver
  end

  private def dequeue_sender
    while sender = @senders.shift?
      if (select_context = sender.select_context) && !select_context.try_trigger
        next
      end

      break
    end

    sender
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  protected def wait_for_receive(value_ptr, state_ptr, select_context)
    @receivers << Receiver(T).new(Fiber.current, value_ptr, state_ptr, select_context)
  end

  protected def unwait_for_receive
    @receivers.delete_if { |receiver| receiver.fiber == Fiber.current }
  end

  protected def wait_for_send(value, state_ptr, select_context)
    @senders << Sender(T).new(Fiber.current, value, state_ptr, select_context)
  end

  protected def unwait_for_send
    @senders.delete_if { |sender| sender.fiber == Fiber.current }
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    _, value = self.select(channels.map(&.receive_select_action))
    value
  end

  def self.send_first(value, *channels)
    send_first value, channels
  end

  def self.send_first(value, channels : Tuple | Array)
    self.select(channels.map(&.send_select_action(value)))
    nil
  end

  def self.select(*ops : SelectAction)
    self.select ops
  end

  def self.select(ops : Indexable(SelectAction))
    i, m = select_impl(ops, false)
    raise "BUG: blocking select returned not ready status" if m.is_a?(NotReady)
    return i, m
  end

  @[Deprecated("Use Channel.non_blocking_select")]
  def self.select(ops : Indexable(SelectAction), has_else)
    # The overload of Channel.select(Indexable(SelectAction), Bool)
    # is used by LiteralExpander with the second argument as `true`.
    # This overload is kept as a transition, but 0.32 will emit calls to
    # Channel.select or Channel.non_blocking_select directly
    non_blocking_select(ops)
  end

  def self.non_blocking_select(*ops : SelectAction)
    self.non_blocking_select ops
  end

  def self.non_blocking_select(ops : Indexable(SelectAction))
    select_impl(ops, true)
  end

  def self.select_impl(ops : Indexable(SelectAction), non_blocking)
    # Sort the operations by the channel they contain
    # This is to avoid deadlocks between concurrent `select` calls
    ops_locks = ops
      .to_a
      .uniq(&.lock_object_id)
      .sort_by(&.lock_object_id)

    ops_locks.each &.lock

    # Check that no channel is closed
    unless ops.all?(&.available?)
      ops_locks.each &.unlock
      raise ClosedError.new
    end

    ops.each_with_index do |op, index|
      result = op.execute

      unless result.is_a?(NotReady)
        ops_locks.each &.unlock
        result = op.default_result if result.is_a?(UseDefault)
        return index, result
      end
    end

    if non_blocking
      ops_locks.each &.unlock
      return ops.size, NotReady.new
    end

    state = Atomic(SelectState).new(SelectState::Active)
    contexts = ops.map &.create_context_and_wait(pointerof(state))

    ops_locks.each &.unlock
    Crystal::Scheduler.reschedule

    ops.each do |op|
      op.lock
      op.unwait
      op.unlock
    end

    contexts.each_with_index do |context, index|
      if context.activated?
        return index, ops[index].wait_result(context)
      end
    end

    raise "BUG: Fiber was awaken from select but no action was activated"
  end

  # :nodoc:
  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  # :nodoc:
  def receive_select_action
    StrictReceiveAction.new(self)
  end

  # :nodoc:
  def receive_select_action?
    LooseReceiveAction.new(self)
  end

  # :nodoc:
  class StrictReceiveAction(T)
    include SelectAction(T)
    property value : T
    property state : DeliveryState

    def initialize(@channel : Channel(T))
      @value = uninitialized T
      @state = DeliveryState::None
    end

    def execute : T | NotReady | UseDefault
      @channel.receive_internal { return NotReady.new }
    end

    def result : T
      @value
    end

    def wait(context : SelectContext(T))
      @channel.wait_for_receive(pointerof(@value), pointerof(@state), context)
    end

    def wait_result_impl(context : SelectContext(T))
      case state
      when DeliveryState::Delivered
        context.action.result
      when DeliveryState::Closed
        raise ClosedError.new
      when DeliveryState::None
        raise "BUG: StrictReceiveAction.wait_result_impl called with DeliveryState::None"
      else
        raise "unreachable"
      end
    end

    def unwait
      @channel.unwait_for_receive
    end

    def lock_object_id
      @channel.object_id
    end

    def lock
      @channel.@lock.lock
    end

    def unlock
      @channel.@lock.unlock
    end

    def available? : Bool
      !@channel.closed?
    end
  end

  # :nodoc:
  class LooseReceiveAction(T)
    include SelectAction(T)
    property value : T
    property state : DeliveryState

    def initialize(@channel : Channel(T))
      @value = uninitialized T
      @state = DeliveryState::None
    end

    def execute : T | NotReady | UseDefault
      @channel.receive_internal do
        return @channel.closed? ? UseDefault.new : NotReady.new
      end
    end

    def result : T
      @value
    end

    def wait(context : SelectContext(T))
      @channel.wait_for_receive(pointerof(@value), pointerof(@state), context)
    end

    def wait_result_impl(context : SelectContext(T))
      case state
      when DeliveryState::Delivered
        context.action.result
      when DeliveryState::Closed
        nil
      when DeliveryState::None
        raise "BUG: LooseReceiveAction.wait_result_impl called with DeliveryState::None"
      else
        raise "unreachable"
      end
    end

    def unwait
      @channel.unwait_for_receive
    end

    def lock_object_id
      @channel.object_id
    end

    def lock
      @channel.@lock.lock
    end

    def unlock
      @channel.@lock.unlock
    end

    def available? : Bool
      # even if the channel is closed the loose receive action can execute
      true
    end

    def default_result
      nil
    end
  end

  # :nodoc:
  class SendAction(T)
    include SelectAction(Nil)
    property state : DeliveryState

    def initialize(@channel : Channel(T), @value : T)
      @state = DeliveryState::None
    end

    def execute : Nil | NotReady | UseDefault
      @channel.send_internal(@value) { return NotReady.new }
      nil
    end

    def result : Nil
      nil
    end

    def wait(context : SelectContext(Nil))
      @channel.wait_for_send(@value, pointerof(@state), context)
    end

    def wait_result_impl(context : SelectContext(Nil))
      case state
      when DeliveryState::Delivered
        context.action.result
      when DeliveryState::Closed
        raise ClosedError.new
      when DeliveryState::None
        raise "BUG: SendAction.wait_result_impl called with DeliveryState::None"
      else
        raise "unreachable"
      end
    end

    def unwait
      @channel.unwait_for_send
    end

    def lock_object_id
      @channel.object_id
    end

    def lock
      @channel.@lock.lock
    end

    def unlock
      @channel.@lock.unlock
    end

    def available? : Bool
      !@channel.closed?
    end
  end
end
