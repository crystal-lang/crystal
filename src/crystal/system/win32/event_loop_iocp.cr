require "c/ioapiset"
require "crystal/system/print_error"

class Crystal::EventLoop
  def self.create : Crystal::EventLoop
    IocpEventLoop.new
  end
end

class Crystal::IocpEventLoop < Crystal::EventLoop
  @@queue = Deque(Event).new

  # Returns the base IO Completion Port
  getter iocp : LibC::HANDLE do
    create_completion_port(LibC::INVALID_HANDLE_VALUE, nil)
  end

  def create_completion_port(handle : LibC::HANDLE, parent : LibC::HANDLE? = iocp)
    iocp = LibC.CreateIoCompletionPort(handle, parent, nil, 0)
    if iocp.null?
      raise IO::Error.from_winerror("CreateIoCompletionPort")
    end
    iocp
  end

  # This is a temporary stub as a stand in for fiber swapping required for concurrency
  def wait_completion(timeout = nil)
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
  def run_once : Nil
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
  def after_fork : Nil
  end

  def enqueue(event : Event)
    unless @@queue.includes?(event)
      @@queue << event
    end
  end

  def dequeue(event : Event)
    @@queue.delete(event)
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::IocpEvent
    Crystal::IocpEvent.new(self, fiber)
  end

  # Create a new timeout event for a fiber.
  def create_timeout_event(fiber : Fiber) : Crystal::IocpEvent
    Crystal::IocpEvent.new(self, fiber)
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::IocpEvent
    Crystal::IocpEvent.new(self, Fiber.current)
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::IocpEvent
    Crystal::IocpEvent.new(self, Fiber.current)
  end
end

struct Crystal::IocpEvent < Crystal::Event
  getter fiber
  getter wake_at

  def initialize(@iocp : Crystal::IocpEventLoop, @fiber : Fiber)
    @wake_at = Time.monotonic
  end

  # Frees the event
  def free : Nil
    @iocp.dequeue(self)
  end

  def add(time_span : Time::Span?) : Nil
    @wake_at = time_span ? Time.monotonic + time_span : Time.monotonic
    @iocp.enqueue(self)
  end
end
