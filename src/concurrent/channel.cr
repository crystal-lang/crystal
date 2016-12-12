require "fiber"
require "select"

abstract class Channel(T)
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
    Scheduler.enqueue(@receivers, receive_token)
    @receivers.clear
    nil
  end

  def closed?
    @closed
  end

  def receive
    receive_impl { raise ClosedError.new }
  end

  def receive?
    receive_impl { return nil }
  end

  def inspect(io)
    to_s(io)
  end

  # :nodoc:
  def activate_receive
    @receivers << Fiber.current
  end

  # :nodoc:
  def deactivate_receive
    @receivers.delete Fiber.current
  end

  # :nodoc:
  def receive_token
    self.as(Void*) + 1
  end

  # :nodoc:
  def activate_send
    @senders << Fiber.current
  end

  # :nodoc:
  def deactivate_send
    @senders.delete Fiber.current
  end

  # :nodoc:
  def send_token
    self.as(Void*) + 2
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    Select.select(channels.map(&.receive_select_action))[1]
  end

  def self.send_first(value, *channels)
    send_first value, channels
  end

  def self.send_first(value, channels : Tuple | Array)
    Select.select(channels.map(&.send_select_action(value)))
    nil
  end

  def self.select(*ops : Select::Action)
    self.select ops
  end

  def self.select(ops : Tuple | Array, has_else = false)
    {{ puts "Warning: Channel.select is deprecated and will be removed after 0.20.0, use Select.select instead".id }}
    Select.select(ops, has_else)
  end

  def send_select_action(value : T)
    SendAction.new(self, value)
  end

  def receive_select_action
    ReceiveAction.new(self)
  end

  private struct ReceiveAction(C)
    include Select::Action::Checkable

    def initialize(@channel : C)
    end

    def ready?
      !@channel.empty?
    end

    def execute
      @channel.receive
    end

    def activate
      @channel.activate_receive
    end

    def deactivate
      @channel.deactivate_receive
    end

    def owns_token?(resume_token)
      resume_token == @channel.receive_token
    end
  end

  private struct SendAction(C, T)
    include Select::Action::Checkable

    def initialize(@channel : C, @value : T)
    end

    def ready?
      !@channel.full?
    end

    def execute
      @channel.send(@value)
    end

    def activate
      @channel.activate_send
    end

    def deactivate
      @channel.deactivate_send
    end

    def owns_token?(resume_token)
      resume_token == @channel.send_token
    end
  end
end

class Channel::Buffered(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Deque(T).new(@capacity)
    super()
  end

  def send(value : T)
    while full?
      raise_if_closed
      @senders << Fiber.current
      Scheduler.reschedule
    end

    raise_if_closed

    @queue << value
    Scheduler.enqueue(@receivers, receive_token)
    @receivers.clear

    self
  end

  private def receive_impl
    while empty?
      yield if @closed
      @receivers << Fiber.current
      Scheduler.reschedule
    end

    @queue.shift.tap do
      Scheduler.enqueue(@senders, send_token)
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

class Channel::Unbuffered(T) < Channel(T)
  @sender : Fiber?

  def initialize
    @has_value = false
    @value = uninitialized T
    super
  end

  def send(value : T)
    while @has_value
      raise_if_closed
      @senders << Fiber.current
      Scheduler.reschedule
    end

    raise_if_closed

    @value = value
    @has_value = true
    @sender = Fiber.current

    if receiver = @receivers.shift?
      receiver.resume(receive_token)
    else
      Scheduler.reschedule
    end
  end

  private def receive_impl
    until @has_value
      yield if @closed
      @receivers << Fiber.current
      if sender = @senders.shift?
        sender.resume(send_token)
      else
        Scheduler.reschedule
      end
    end

    yield if @closed

    @value.tap do
      @has_value = false
      Scheduler.enqueue(@sender.not_nil!, send_token)
    end
  end

  def empty?
    !@has_value
  end

  def full?
    @has_value || @receivers.empty?
  end
end
