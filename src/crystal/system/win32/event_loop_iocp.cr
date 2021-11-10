require "c/ioapiset"
require "crystal/system/print_error"

module Crystal::EventLoop
  @@queue = Deque(Event).new

  # Returns the base IO Completion Port
  class_getter iocp : LibC::HANDLE do
    create_completion_port(LibC::INVALID_HANDLE_VALUE, nil)
  end

  def self.create
    Crystal::EventLoop
  end

  def self.create_completion_port(handle : LibC::HANDLE, parent : LibC::HANDLE? = iocp)
    iocp = LibC.CreateIoCompletionPort(handle, parent, nil, 0)
    if iocp.null?
      raise IO::Error.from_winerror("CreateIoCompletionPort")
    end
    iocp
  end

  # This is a temporary stub as a stand in for fiber swapping required for concurrency
  def self.wait_completion(timeout = nil)
    result = LibC.GetQueuedCompletionStatusEx(iocp, out io_entry, 1, out removed, timeout, false)
    if result == 0
      error = WinError.value
      if timeout && error.wait_timeout?
        return false
      else
        raise IO::Error.from_os_error("GetQueuedCompletionStatusEx", error)
      end
    end

    true
  end

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
