require "crystal/system/print_error"

module Crystal::EventLoop
  @@queue = Deque(Fiber).new

  # Runs the event loop.
  def self.run_once : Nil
    next_fiber = @@queue.pop?

    if next_fiber
      Crystal::Scheduler.enqueue next_fiber
    end
  end

  # Reinitializes the event loop after a fork.
  def self.after_fork : Nil
  end

  def self.enqueue(fiber : Fiber)
    unless @@queue.includes?(fiber)
      @@queue << fiber
    end
  end

  def self.dequeue(fiber : Fiber)
    @@queue.delete(fiber)
  end

  # Create a new resume event for a fiber.
  def self.create_resume_event(fiber : Fiber) : Crystal::Event
    enqueue(fiber)

    Crystal::Event.new(fiber)
  end

  # Creates a write event for a file descriptor.
  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::Event.new(Fiber.current)
  end

  # Creates a read event for a file descriptor.
  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::Event.new(Fiber.current)
  end
end

struct Crystal::Event
  def initialize(@fiber : Fiber)
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.dequeue(@fiber)
  end

  def add(time_span : Time::Span?) : Nil
    Crystal::EventLoop.enqueue(@fiber)
  end
end
