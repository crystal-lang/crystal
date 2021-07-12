require "crystal/system/print_error"

module Crystal::EventLoop
  @@queue = Deque(Event).new

  # Runs the event loop.
  def self.run_once : Nil
    next_event = @@queue.min_by { |e| e.wake_at }

    if next_event
      sleep_time = next_event.wake_at - Time.monotonic

      if sleep_time > Time::Span.zero
        LibC.Sleep(sleep_time.total_milliseconds)
      end

      dequeue next_event

      Crystal::Scheduler.enqueue next_event.fiber
    else
      Crystal::System.print_error "Warning: No runnables in scheduler. Exiting program.\n"
      ::exit
    end
  end

  # Reinitializes the event loop after a fork.
  def self.after_fork : Nil
  end

  def self.enqueue(event : Event)
    unless @@queue.includes?(event)
      @@queue << event
    end
  end

  def self.dequeue(event : Event)
    @@queue.delete(event)
  end

  # Create a new resume event for a fiber.
  def self.create_resume_event(fiber : Fiber) : Crystal::Event
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
  getter fiber
  getter wake_at

  def initialize(@fiber : Fiber)
    @wake_at = Time.monotonic
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.dequeue(self)
  end

  def add(time_span : Time::Span) : Nil
    @wake_at = Time.monotonic + time_span
    Crystal::EventLoop.enqueue(self)
  end
end
