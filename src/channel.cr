require "fiber"

# Channels enable concurrent communication between fibers.

# ```
# channel = Channel(Nil).new
#
# spawn do
#   puts "Before send"
#   channel.send(nil)
#   puts "After send"
# end
#
# puts "Before receive"
# channel.receive
# puts "After receive"
# ```
abstract class Channel(T)
  module SelectAction
    abstract def ready?
    abstract def execute
    abstract def wait
    abstract def unwait
  end

  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  def initialize
    @closed = false
    @senders = Deque(Fiber).new
    @receivers = Deque(Fiber).new
  end

  def self.new : Unbuffered(T)
    Unbuffered(T).new
  end

  def self.new(capacity) : Buffered(T)
    Buffered(T).new(capacity)
  end

  def close
    @closed = true
    Crystal::Scheduler.enqueue @senders
    @senders.clear
    Crystal::Scheduler.enqueue @receivers
    @receivers.clear
    nil
  end

  def closed?
    @closed
  end

  # Receive a value from the channel.
  #
  # ```
  # channel = Channel(Int32).new
  # channel.send(1)
  # channel.receive # => 1
  # ```
  def receive
    receive_impl { raise ClosedError.new }
  end

  # Receive a value from the channel, if any.
  def receive?
    receive_impl { return nil }
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  protected def wait_for_receive
    @receivers << Fiber.current
  end

  protected def unwait_for_receive
    @receivers.delete Fiber.current
  end

  protected def wait_for_send
    @senders << Fiber.current
  end

  protected def unwait_for_send
    @senders.delete Fiber.current
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    self.select(channels.map(&.receive_select_action))[1]
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

  def self.select(ops : Tuple | Array, has_else = false)
    loop do
      ops.each_with_index do |op, index|
        if op.ready?
          result = op.execute
          return index, result
        end
      end

      if has_else
        return ops.size, nil
      end

      ops.each &.wait
      Crystal::Scheduler.reschedule
      ops.each &.unwait
    end
  end

  # :nodoc:
  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  # :nodoc:
  def receive_select_action
    ReceiveAction.new(self)
  end

  # Defines the receive actions for a channel.
  struct ReceiveAction(C)
    include SelectAction

    def initialize(@channel : C)
    end

    # Checks if the channel is ready.
    def ready?
      !@channel.empty?
    end

    # Receive the value to the channel.
    def execute
      @channel.receive
    end

    # Wait for the channel to receive the value.
    def wait
      @channel.wait_for_receive
    end

    # Do not wait to receive the value from the channel anymore.
    def unwait
      @channel.unwait_for_receive
    end
  end

  # Defines the send actions for a channel.
  struct SendAction(C, T)
    include SelectAction

    def initialize(@channel : C, @value : T)
    end

    # Checks if the channel is ready.
    def ready?
      !@channel.full?
    end

    # Sends the value to the channel.
    def execute
      @channel.send(@value)
    end

    # Wait for the channel to send the value.
    def wait
      @channel.wait_for_send
    end

    # Do not wait for the channel to send the value anymore.
    def unwait
      @channel.unwait_for_send
    end
  end
end

# Buffered channel, using a queue.
class Channel::Buffered(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Deque(T).new(@capacity)
    super()
  end

  # Send a value to the channel.
  def send(value : T)
    while full?
      raise_if_closed
      @senders << Fiber.current
      Crystal::Scheduler.reschedule
    end

    raise_if_closed

    @queue << value
    Crystal::Scheduler.enqueue @receivers
    @receivers.clear

    self
  end

  private def receive_impl
    while empty?
      yield if @closed
      @receivers << Fiber.current
      Crystal::Scheduler.reschedule
    end

    @queue.shift.tap do
      Crystal::Scheduler.enqueue @senders
      @senders.clear
    end
  end

  def full?
    @queue.size >= @capacity
  end

  def empty?
    @queue.empty?
  end
end

# Unbuffered channel.
class Channel::Unbuffered(T) < Channel(T)
  @sender : Fiber?

  def initialize
    @has_value = false
    @value = uninitialized T
    super
  end

  # Send a value to the channel.
  def send(value : T)
    while @has_value
      raise_if_closed
      @senders << Fiber.current
      Crystal::Scheduler.reschedule
    end

    raise_if_closed

    @value = value
    @has_value = true
    @sender = Fiber.current

    if receiver = @receivers.shift?
      receiver.resume
    else
      Crystal::Scheduler.reschedule
    end
  end

  private def receive_impl
    until @has_value
      yield if @closed
      @receivers << Fiber.current
      if sender = @senders.shift?
        sender.resume
      else
        Crystal::Scheduler.reschedule
      end
    end

    yield if @closed

    @value.tap do
      @has_value = false
      Crystal::Scheduler.enqueue @sender.not_nil!
      @sender = nil
    end
  end

  def empty?
    !@has_value && @senders.empty?
  end

  def full?
    @has_value || @receivers.empty?
  end

  def close
    super
    if sender = @sender
      Crystal::Scheduler.enqueue sender
      @sender = nil
    end
  end
end
