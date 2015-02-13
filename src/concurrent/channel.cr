require "fiber"

class Channel(T)
  def initialize(@capacity = 32)
    @queue = [] of T
    @senders = [] of Fiber
    @receivers = [] of Fiber
  end

  def send(value : T)
    while full?
      @senders << Fiber.current.not_nil!
      Fiber.yield
    end

    @queue << value
    while @receivers.any?
      @receivers.shift.resume
      break if empty?
    end
  end

  def receive
    while empty?
      @receivers << Fiber.current.not_nil!
      Fiber.yield
    end

    @queue.shift.tap do
      while @senders.any?
        @senders.shift.resume
        break if full?
      end
    end
  end

  def full?
    @queue.length >= @capacity
  end

  def empty?
    @queue.empty?
  end
end
