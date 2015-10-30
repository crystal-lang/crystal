require "fiber"

abstract class Channel(T)
  class ClosedError < Exception
    def initialize(msg = "Channel is closed")
      super(msg)
    end
  end

  def initialize
    @closed = false
    @senders = [] of Fiber
    @receivers = [] of Fiber
  end

  def self.new
    Unbuffered(T).new
  end

  def self.new(capacity)
    Buffered(T).new(capacity)
  end

  def close
    @closed = true
    Scheduler.enqueue @receivers
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

  def wait_for_receive
    @receivers << Fiber.current
  end

  def unwait_for_receive
    @receivers.delete Fiber.current
  end

  def wait_for_send
    @senders << Fiber.current
  end

  def unwait_for_send
    @senders.delete Fiber.current
  end

  protected def raise_if_closed
    raise ClosedError.new if @closed
  end

  def self.receive_first(*channels)
    receive_first channels
  end

  def self.receive_first(channels : Tuple | Array)
    select(channels.map(&.receive_op))[1]
  end

  def self.send_first(value, *channels)
    send_first value, channels
  end

  def self.send_first(value, channels : Tuple | Array)
    select(channels.map(&.send_op(value)))
    nil
  end

  def self.select(*ops : SendOp | ReceiveOp)
    select ops
  end

  def self.select(ops : Tuple | Array)
    loop do
      ops.each_with_index do |op, index|
        if op.ready?
          result = op.execute
          return index, result
        end
      end

      ops.each &.wait
      Scheduler.reschedule
      ops.each &.unwait
    end
  end

  def send_op(value : T)
    SendOp.new(self, value)
  end

  def receive_op
    ReceiveOp.new(self)
  end

  struct ReceiveOp(T)
    def initialize(@channel : Channel(T))
    end

    def ready?
      !@channel.empty?
    end

    def execute
      @channel.receive
    end

    def wait
      @channel.wait_for_receive
    end

    def unwait
      @channel.unwait_for_receive
    end
  end

  struct SendOp(T)
    def initialize(@channel : Channel(T), @value : T)
    end

    def ready?
      !@channel.full?
    end

    def execute
      @channel.send(@value)
    end

    def wait
      @channel.wait_for_send
    end

    def unwait
      @channel.unwait_for_send
    end
  end
end

class Channel::Buffered(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Array(T).new(@capacity)
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
    Scheduler.enqueue @receivers
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
      Scheduler.enqueue @senders
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
  def initialize
    @has_value = false
    @value :: T
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

    if receiver = @receivers.pop?
      receiver.resume
    else
      Scheduler.reschedule
    end
  end

  private def receive_impl
    until @has_value
      yield if @closed
      @receivers << Fiber.current
      if sender = @senders.pop?
        sender.resume
      else
        Scheduler.reschedule
      end
    end

    yield if @closed

    @value.tap do
      @has_value = false
      Scheduler.enqueue @sender.not_nil!
    end
  end

  def empty?
    !@has_value
  end

  def full?
    @has_value || @receivers.empty?
  end
end
