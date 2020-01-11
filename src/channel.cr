require "fiber"
require "crystal/spin_lock"
require "crystal/pointer_linked_list"

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
    abstract def execute : DeliveryState
    abstract def wait(context : SelectContext(S))
    abstract def wait_result_impl(context : SelectContext(S))
    abstract def unwait_impl(context : SelectContext(S))
    abstract def result : S
    abstract def lock_object_id
    abstract def lock
    abstract def unlock

    def create_context_and_wait(shared_state)
      context = SelectContext.new(shared_state, self)
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

    # idem wait_result/wait_result_impl
    def unwait(context : SelectContext)
      raise "BUG: Unexpected call to #{typeof(self)}#unwait(context : #{typeof(context)})"
    end

    def unwait(context : SelectContext(S))
      unwait_impl(context)
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

  private class SelectContextSharedState
    @state : Atomic(SelectState)

    def initialize(value : SelectState)
      @state = Atomic(SelectState).new(value)
    end

    def compare_and_set(cmp : SelectState, new : SelectState) : {SelectState, Bool}
      @state.compare_and_set(cmp, new)
    end
  end

  private class SelectContext(S)
    @state : SelectContextSharedState
    property action : SelectAction(S)
    @activated = false

    def initialize(@state, @action : SelectAction(S))
    end

    def activated?
      @activated
    end

    def try_trigger : Bool
      _, succeed = @state.compare_and_set(:active, :done)
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

  private module SenderReceiverCloseAction
    def close
      self.state = DeliveryState::Closed
      _select_context = self.select_context
      if _select_context.nil? || _select_context.try_trigger
        self.fiber.enqueue
      end
    end
  end

  private struct Sender(T)
    include Crystal::PointerLinkedList::Node
    include SenderReceiverCloseAction

    property fiber : Fiber
    property data : T
    property state : DeliveryState
    property select_context : SelectContext(Nil)?

    def initialize
      @fiber = uninitialized Fiber
      @data = uninitialized T
      @state = DeliveryState::None
    end
  end

  private struct Receiver(T)
    include Crystal::PointerLinkedList::Node
    include SenderReceiverCloseAction

    property fiber : Fiber
    property data : T
    property state : DeliveryState
    property select_context : SelectContext(T)?

    def initialize
      @fiber = uninitialized Fiber
      @data = uninitialized T
      @state = DeliveryState::None
    end
  end

  def initialize(@capacity = 0)
    @closed = false

    @senders = Crystal::PointerLinkedList(Sender(T)).new
    @receivers = Crystal::PointerLinkedList(Receiver(T)).new

    if capacity > 0
      @queue = Deque(T).new(capacity)
    end
  end

  # Closes the channel.
  # The method prevents any new value from being sent to / received from the channel.
  # All fibers blocked in `send` or `receive` will be awakened with `Channel::ClosedError`
  #
  # Both awaiting and subsequent calls to `#send` will consider the channel closed.
  # All items successfully sent to the channel can be received, before `#receive` considers the channel closed.
  # Calling `#close` on a closed channel does not have any effect.
  def close : Nil
    sender_list = Crystal::PointerLinkedList(Sender(T)).new
    receiver_list = Crystal::PointerLinkedList(Receiver(T)).new

    @lock.sync do
      @closed = true

      @senders, sender_list = sender_list, @senders
      @receivers, receiver_list = receiver_list, @receivers
    end

    sender_list.each(&.value.close)
    receiver_list.each(&.value.close)
  end

  def closed?
    @closed
  end

  # Sends a value to the channel.
  # If the channel has spare capacity, then the method returns immediately.
  # Otherwise, this method blocks the calling fiber until another fiber calls `#receive` on the channel.
  #
  # Raises `ClosedError` if the channel is closed or closes while waiting on a full channel.
  def send(value : T)
    sender = Sender(T).new

    @lock.lock

    case send_internal(value)
    when DeliveryState::Delivered
      @lock.unlock
    when DeliveryState::Closed
      @lock.unlock
      raise ClosedError.new
    else
      sender.fiber = Fiber.current
      sender.data = value
      @senders.push pointerof(sender)
      @lock.unlock

      Crystal::Scheduler.reschedule

      case sender.state
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

  protected def send_internal(value : T)
    if @closed
      DeliveryState::Closed
    elsif receiver_ptr = dequeue_receiver
      receiver_ptr.value.data = value
      receiver_ptr.value.state = DeliveryState::Delivered
      receiver_ptr.value.fiber.enqueue

      DeliveryState::Delivered
    elsif (queue = @queue) && queue.size < @capacity
      queue << value

      DeliveryState::Delivered
    else
      DeliveryState::None
    end
  end

  # Receives a value from the channel.
  # If there is a value waiting, then it is returned immediately. Otherwise, this method blocks until a value is sent to the channel.
  #
  # Raises `ClosedError` if the channel is closed or closes while waiting for receive.
  #
  # ```
  # channel = Channel(Int32).new
  # spawn do
  #   channel.send(1)
  # end
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
    receiver = Receiver(T).new

    @lock.lock

    state, value = receive_internal

    case state
    when DeliveryState::Delivered
      @lock.unlock
      raise "BUG: Unexpected UseDefault value for delivered receive" if value.is_a?(UseDefault)
      value
    when DeliveryState::Closed
      @lock.unlock
      yield
    else
      receiver.fiber = Fiber.current
      @receivers.push pointerof(receiver)
      @lock.unlock

      Crystal::Scheduler.reschedule

      case receiver.state
      when DeliveryState::Delivered
        receiver.data
      when DeliveryState::Closed
        yield
      else
        raise "BUG: Fiber was awaken without channel delivery state set"
      end
    end
  end

  def receive_internal
    if (queue = @queue) && !queue.empty?
      deque_value = queue.shift
      if sender_ptr = dequeue_sender
        queue << sender_ptr.value.data
        sender_ptr.value.state = DeliveryState::Delivered
        sender_ptr.value.fiber.enqueue
      end

      {DeliveryState::Delivered, deque_value}
    elsif sender_ptr = dequeue_sender
      value = sender_ptr.value.data
      sender_ptr.value.state = DeliveryState::Delivered
      sender_ptr.value.fiber.enqueue

      {DeliveryState::Delivered, value}
    elsif @closed
      {DeliveryState::Closed, UseDefault.new}
    else
      {DeliveryState::None, UseDefault.new}
    end
  end

  private def dequeue_receiver
    while receiver_ptr = @receivers.shift?
      select_context = receiver_ptr.value.select_context
      if select_context && !select_context.try_trigger
        receiver_ptr.value.state = DeliveryState::Delivered
        next
      end

      break
    end

    receiver_ptr
  end

  private def dequeue_sender
    while sender_ptr = @senders.shift?
      select_context = sender_ptr.value.select_context
      if select_context && !select_context.try_trigger
        sender_ptr.value.state = DeliveryState::Delivered
        next
      end

      break
    end

    sender_ptr
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
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

    ops.each_with_index do |op, index|
      state = op.execute

      case state
      when DeliveryState::Delivered
        ops_locks.each &.unlock
        return index, op.result
      when DeliveryState::Closed
        ops_locks.each &.unlock
        return index, op.default_result
      else
        # do nothing
      end
    end

    if non_blocking
      ops_locks.each &.unlock
      return ops.size, NotReady.new
    end

    # Because `channel#close` may clean up a long list, `select_context.try_trigger` may
    # be called after the select return. In order to prevent invalid address access,
    # the state is allocated in the heap.
    shared_state = SelectContextSharedState.new(SelectState::Active)
    contexts = ops.map &.create_context_and_wait(shared_state)

    ops_locks.each &.unlock
    Crystal::Scheduler.reschedule

    contexts.each_with_index do |context, index|
      op = ops[index]
      op.lock
      op.unwait(context)
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
    property receiver : Receiver(T)

    def initialize(@channel : Channel(T))
      @receiver = Receiver(T).new
    end

    def execute : DeliveryState
      state, value = @channel.receive_internal

      if state.delivered?
        @receiver.data = value.as(T)
      end

      state
    end

    def result : T
      @receiver.data
    end

    def wait(context : SelectContext(T))
      @receiver.fiber = Fiber.current
      @receiver.select_context = context
      @channel.@receivers.push pointerof(@receiver)
    end

    def wait_result_impl(context : SelectContext(T))
      case @receiver.state
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

    def unwait_impl(context : SelectContext(T))
      if !@channel.closed? && @receiver.state.none?
        @channel.@receivers.delete pointerof(@receiver)
      end
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

    def default_result
      raise ClosedError.new
    end
  end

  # :nodoc:
  class LooseReceiveAction(T)
    include SelectAction(T)
    property receiver : Receiver(T)

    def initialize(@channel : Channel(T))
      @receiver = Receiver(T).new
    end

    def execute : DeliveryState
      state, value = @channel.receive_internal

      if state.delivered?
        @receiver.data = value.as(T)
      end

      state
    end

    def result : T
      @receiver.data
    end

    def wait(context : SelectContext(T))
      @receiver.fiber = Fiber.current
      @receiver.select_context = context
      @channel.@receivers.push pointerof(@receiver)
    end

    def wait_result_impl(context : SelectContext(T))
      case @receiver.state
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

    def unwait_impl(context : SelectContext(T))
      if !@channel.closed? && @receiver.state.none?
        @channel.@receivers.delete pointerof(@receiver)
      end
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

    def default_result
      nil
    end
  end

  # :nodoc:
  class SendAction(T)
    include SelectAction(Nil)
    property sender : Sender(T)

    def initialize(@channel : Channel(T), value : T)
      @sender = Sender(T).new
      @sender.data = value
    end

    def execute : DeliveryState
      @channel.send_internal(@sender.data)
    end

    def result : Nil
      nil
    end

    def wait(context : SelectContext(Nil))
      @sender.fiber = Fiber.current
      @sender.select_context = context
      @channel.@senders.push pointerof(@sender)
    end

    def wait_result_impl(context : SelectContext(Nil))
      case @sender.state
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

    def unwait_impl(context : SelectContext(Nil))
      if !@channel.closed? && @sender.state.none?
        @channel.@senders.delete pointerof(@sender)
      end
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

    def default_result
      raise ClosedError.new
    end
  end

  # :nodoc:
  class TimeoutAction
    include SelectAction(Nil)

    # Total amount of time to wait
    @timeout : Time::Span
    @select_context : SelectContext(Nil)?

    def initialize(@timeout : Time::Span)
    end

    def execute : DeliveryState
      DeliveryState::None
    end

    def result : Nil
      nil
    end

    def wait(context : SelectContext(Nil))
      @select_context = context
      Fiber.timeout(@timeout, self)
    end

    def wait_result_impl(context : SelectContext(Nil))
      nil
    end

    def unwait_impl(context : SelectContext(Nil))
      Fiber.cancel_timeout
    end

    def lock_object_id
      self.object_id
    end

    def lock
    end

    def unlock
    end

    def time_expired(fiber : Fiber) : Nil
      if @select_context.try &.try_trigger
        Crystal::Scheduler.enqueue fiber
      end
    end
  end
end

# Timeout keyword for use in `select`.
#
# ```
# select
# when x = ch.recieve
#   puts "got #{x}"
# when timeout(1.seconds)
#   puts "timeout"
# end
# ```
#
# NOTE: It won't trigger if the `select` has an `else` case (i.e.: a non-blocking select).
#
# NOTE: Using negative amounts will cause the timeout to not trigger.
#
def timeout_select_action(timeout : Time::Span)
  Channel::TimeoutAction.new(timeout)
end
