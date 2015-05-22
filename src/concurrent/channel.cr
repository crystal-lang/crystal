require "fiber"

class ChannelClosed < Exception
  def initialize
    super("Channel is closed")
  end
end

abstract class Channel(T)
  def initialize
    @closed = false
    @senders = [] of Fiber
    @receivers = [] of Fiber
  end

  def self.new
    UnbufferedChannel(T).new
  end

  def self.new(capacity)
    BufferedChannel(T).new(capacity)
  end

  def close
    @closed = true
    Scheduler.enqueue @receivers
    @receivers.clear
  end

  def closed?
    @closed
  end

  def receive
    receive_impl { raise ChannelClosed.new }
  end

  def receive?
    receive_impl { return nil }
  end

  def self.select(*channels)
    loop do
      ready_channel = channels.find &.ready?
      return ready_channel if ready_channel

      channels.each &.wait
      Scheduler.reschedule
      channels.each &.unwait
    end
  end

  protected def wait
    @receivers << Fiber.current
  end

  protected def unwait
    @receivers.delete Fiber.current
  end

  protected def raise_if_closed
    raise ChannelClosed.new if @closed
  end
end

class BufferedChannel(T) < Channel(T)
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
    @queue.length >= @capacity
  end

  def empty?
    @queue.empty?
  end

  def ready?
    !empty?
  end
end

class UnbufferedChannel(T) < Channel(T)
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

  def ready?
    @has_value
  end
end
