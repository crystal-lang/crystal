{% skip_file unless flag?(:linux) %}

require "./event_io_uring"

# :nodoc:
class Crystal::IoUringEventLoop < Crystal::EventLoop
  private getter(io_uring) { Crystal::System::IoUring.new(128) }

  {% unless flag?(:preview_mt) %}
    # Reinitializes the event loop after a fork.
    def after_fork : Nil
      @io_uring = nil
    end
  {% end %}

  # Runs the event loop.
  def run_once : Nil
    io_uring.process_completion_events(blocking: true)
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::Event
    Crystal::IoUringEvent.new(io_uring, :resume, 0) do |res|
      Crystal::Scheduler.enqueue fiber
    end
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : Crystal::Event
    Crystal::IoUringEvent.new(io_uring, :timeout, 0) do |res|
      next if res == -Errno::ECANCELED.value
      if select_action = fiber.timeout_select_action
        fiber.timeout_select_action = nil
        select_action.time_expired(fiber)
      else
        Crystal::Scheduler.enqueue fiber
      end
    end
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::IoUringEvent.new(io_uring, :writable_fd, io.fd) do |res|
      if res == -Errno::ECANCELED.value
        io.resume_write(timed_out: true)
      else
        io.resume_write
      end
    end
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::IoUringEvent.new(io_uring, :readable_fd, io.fd) do |res|
      if res == -Errno::ECANCELED.value
        io.resume_read(timed_out: true)
      else
        io.resume_read
      end
    end
  end
end
