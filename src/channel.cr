require "fiber"
require "crystal/spin_lock"
require "crystal/pointer_linked_list"
require "channel/select"

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
# NOTE: Although a `Channel(Nil)` or any other nilable types like `Channel(Int32?)` are valid
# they are discouraged since from certain methods or constructs it receiving a `nil` as data
# will be indistinguishable from a closed channel.
#
class Channel(T)
  include Iterator(T)

  @lock = Crystal::SpinLock.new
  @queue : Deque(T)?

  # :nodoc:
  record UseDefault

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  private module SenderReceiverCloseAction
    property cancelation_token : Fiber::CancelationToken?

    def claim? : Bool
      if token = @cancelation_token
        fiber.try_cancel?(token)
      else
        true
      end
    end

    def close
      return unless claim?

      self.state = DeliveryState::Closed
      self.fiber.enqueue
    end
  end

  private struct Sender(T)
    include Crystal::PointerLinkedList::Node
    include SenderReceiverCloseAction

    property fiber : Fiber
    property data : T
    property state : DeliveryState

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
  # The method prevents any new value from being sent to the channel.
  #
  # If the channel has buffered values, then subsequent calls to `#receive` and `#receive?` will
  # succeed and consume the buffer until it is empty.
  #
  # All fibers blocked in `send` or `receive` will be awakened with `Channel::ClosedError`.
  # All subsequent calls to `#send` will consider the channel closed.
  # Subsequent calls to `#receive` and `#receive?` will consider the channel closed once the
  # buffer is empty.
  #
  # Calling `#close` on a closed channel does not have any effect.
  #
  # It returns `true` when the channel was successfully closed, or `false` if it was already closed.
  def close : Bool
    sender_list = Crystal::PointerLinkedList(Sender(T)).new
    receiver_list = Crystal::PointerLinkedList(Receiver(T)).new

    @lock.sync do
      return false if @closed
      @closed = true

      @senders, sender_list = sender_list, @senders
      @receivers, receiver_list = receiver_list, @receivers
    end

    sender_list.each(&.value.close)
    receiver_list.each(&.value.close)
    true
  end

  # Returns `true` if this channel has been closed for new submissions.
  #
  # NOTE: A closed buffered channel continues to deliver remaining buffered values
  # through `#receive` and `#receive?` until the internal buffer is drained.
  def closed? : Bool
    @closed
  end

  # Sends a value to the channel.
  # If the channel has spare capacity, then the method returns immediately.
  # Otherwise, this method blocks the calling fiber until another fiber calls `#receive` on the channel.
  #
  # Raises `ClosedError` if the channel is closed or closes while waiting on a full channel.
  def send(value : T) : self
    sender = Sender(T).new

    @lock.lock

    case send_internal(value)
    in .delivered?
      @lock.unlock
    in .closed?
      @lock.unlock
      raise ClosedError.new
    in .none?
      sender.fiber = Fiber.current
      sender.data = value
      @senders.push pointerof(sender)
      @lock.unlock

      Fiber.suspend

      case sender.state
      in .delivered?
        # ignore
      in .closed?
        raise ClosedError.new
      in .none?
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
  #
  # If there is a value waiting, then it is returned immediately. Otherwise, this method blocks until a value is sent to the channel.
  #
  # For buffered channels, remaining values in the buffer are delivered first even if the channel is closed.
  #
  # Raises `ClosedError` if the channel is closed (with no buffered values remaining) or closes while waiting for receive.
  #
  # ```
  # channel = Channel(Int32).new
  # spawn do
  #   channel.send(1)
  # end
  # channel.receive # => 1
  # ```
  def receive : T
    receive_impl { raise ClosedError.new }
  end

  # Receives a value from the channel.
  #
  # If there is a value waiting, it is returned immediately. Otherwise, this method blocks until a value is sent to the channel.
  #
  # For buffered channels, remaining values in the buffer are delivered first even if the channel is closed.
  #
  # Returns `nil` if the channel is closed (with no buffered values remaining) or closes while waiting for receive.
  def receive? : T?
    receive_impl { return nil }
  end

  private def receive_impl(&)
    receiver = Receiver(T).new

    @lock.lock

    state, value = receive_internal

    case state
    in .delivered?
      @lock.unlock
      raise "BUG: Unexpected UseDefault value for delivered receive" if value.is_a?(UseDefault)
      value
    in .closed?
      @lock.unlock
      yield
    in .none?
      receiver.fiber = Fiber.current
      @receivers.push pointerof(receiver)
      @lock.unlock

      Fiber.suspend

      case receiver.state
      in .delivered?
        receiver.data
      in .closed?
        yield
      in .none?
        raise "BUG: Fiber was awaken without channel delivery state set"
      end
    end
  end

  protected def receive_internal
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
      break if receiver_ptr.value.claim?
    end
    receiver_ptr
  end

  private def dequeue_sender
    while sender_ptr = @senders.shift?
      break if sender_ptr.value.claim?
    end
    sender_ptr
  end

  def next : T | Stop
    receive_impl { stop }
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

  def self.receive_first(channels : Enumerable(Channel))
    _, value = self.select(channels.map(&.receive_select_action))
    value
  end

  def self.send_first(value, *channels) : Nil
    send_first value, channels
  end

  def self.send_first(value, channels : Enumerable(Channel)) : Nil
    self.select(channels.map(&.send_select_action(value)))
    nil
  end

  # Overrides `Iterator#tap` to restore the original implementation of `Object#tap`.
  def tap(&) : self
    # FIXME: This method is a workaround and should be removed once we have cleared the `Iterator` interface.

    yield self
    self
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

  private class StrictReceiveAction(T)
    include SelectAction(T)
    @receiver : Receiver(T)

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

    def wait(fiber : Fiber, token : Fiber::CancelationToken) : Nil
      @receiver.fiber = fiber
      @receiver.cancelation_token = token
      @channel.@receivers.push pointerof(@receiver)
    end

    def delivery_state : DeliveryState
      @receiver.state
    end

    def unwait : Nil
      if !@channel.closed? && @receiver.next
        @channel.@receivers.delete pointerof(@receiver)
      end
    end

    def lock_object_id : UInt64
      @channel.object_id
    end

    def lock : Nil
      @channel.@lock.lock
    end

    def unlock : Nil
      @channel.@lock.unlock
    end

    def default_result
      raise ClosedError.new
    end
  end

  private class LooseReceiveAction(T)
    include SelectAction(T)
    @receiver : Receiver(T)

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

    def wait(fiber : Fiber, token : Fiber::CancelationToken) : Nil
      @receiver.fiber = fiber
      @receiver.cancelation_token = token
      @channel.@receivers.push pointerof(@receiver)
    end

    def delivery_state : DeliveryState
      @receiver.state
    end

    def unwait : Nil
      if !@channel.closed? && @receiver.next
        @channel.@receivers.delete pointerof(@receiver)
      end
    end

    def lock_object_id : UInt64
      @channel.object_id
    end

    def lock : Nil
      @channel.@lock.lock
    end

    def unlock : Nil
      @channel.@lock.unlock
    end

    def default_result
      nil
    end
  end

  private class SendAction(T)
    include SelectAction(Nil)
    @sender : Sender(T)

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

    def wait(fiber : Fiber, token : Fiber::CancelationToken) : Nil
      @sender.fiber = fiber
      @sender.cancelation_token = token
      @channel.@senders.push pointerof(@sender)
    end

    def delivery_state : DeliveryState
      @sender.state
    end

    def unwait : Nil
      if !@channel.closed? && @sender.next
        @channel.@senders.delete pointerof(@sender)
      end
    end

    def lock_object_id : UInt64
      @channel.object_id
    end

    def lock : Nil
      @channel.@lock.lock
    end

    def unlock : Nil
      @channel.@lock.unlock
    end

    def default_result
      raise ClosedError.new
    end
  end
end
