require "c/ioapiset"
require "crystal/system/print_error"

class Crystal::EventLoop
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
      now = Time.monotonic

      if next_event.wake_at > now
        sleep_time = next_event.wake_at - now
        timed_out = IO::Overlapped.wait_queued_completions(sleep_time.total_milliseconds) do |fiber|
          Crystal::Scheduler.enqueue fiber
        end

        return unless timed_out
      end

      dequeue next_event

      fiber = next_event.fiber

      unless fiber.dead?
        if next_event.timeout? && (select_action = fiber.timeout_select_action)
          fiber.timeout_select_action = nil
          select_action.time_expired(fiber)
        else
          Crystal::Scheduler.enqueue fiber
        end
      end
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
    Crystal::IocpEvent.new(fiber)
  end

  # Creates a write event for a file descriptor.
  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::IocpEvent.new(Fiber.current)
  end

  # Creates a read event for a file descriptor.
  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::IocpEvent.new(Fiber.current)
  end

  def self.create_timeout_event(fiber)
    Crystal::Event.new(fiber, timeout: true)
  end
end

struct Crystal::IocpEvent < Crystal::Event
  getter fiber
  getter wake_at
  getter? timeout

  def initialize(@fiber : Fiber, @wake_at = Time.monotonic, *, @timeout = false)
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.dequeue(self)
  end

  def delete
    free
  end
  
  def add(time_span : Time::Span?) : Nil
    @wake_at = time_span ? Time.monotonic + time_span : Time.monotonic
    Crystal::EventLoop.enqueue(self)
  end
end
