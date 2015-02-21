require "fiber"

abstract class Channel(T)
  def initialize
    @senders = [] of Fiber
    @receivers = [] of Fiber
  end

  def self.new
    UnbufferedChannel(T).new
  end

  def self.new(capacity)
    BufferedChannel(T).new(capacity)
  end
end

class BufferedChannel(T) < Channel(T)
  def initialize(@capacity = 32)
    @queue = Array(T).new(@capacity)
    super()
  end

  def send(value : T)
    while full?
      @senders << Fiber.current
      Scheduler.reschedule
    end

    @queue << value
    Scheduler.enqueue @receivers
    @receivers.clear
  end

  def receive
    while empty?
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
end

class UnbufferedChannel(T) < Channel(T)
  def send(value : T)
    while @value || @receivers.empty?
      @senders << Fiber.current
      Scheduler.reschedule
    end

    @value = value

    receiver = @receivers.pop
    Scheduler.enqueue Fiber.current
    receiver.resume
  end

  def receive
    while @value.nil?
      @receivers << Fiber.current
      if @senders.any?
        @senders.pop.resume
      else
        Scheduler.reschedule
      end
    end

    @value.not_nil!.tap do
      @value = nil
    end
  end
end
