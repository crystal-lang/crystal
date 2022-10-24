# :nodoc:
abstract class Crystal::EventLoop
  def self.create
    Crystal::WasiEventLoop.new
  end
end

# :nodoc:
class Crystal::WasiEventLoop < Crystal::EventLoop
  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
    end
  {% end %}

  # Runs the event loop.
  def run_once : Nil
    raise NotImplementedError.new("Crystal::WasiEventLoop.run_once")
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::Event
    raise NotImplementedError.new("Crystal::WasiEventLoop.create_resume_event")
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : Crystal::Event
    raise NotImplementedError.new("Crystal::WasiEventLoop.create_timeout_event")
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    raise NotImplementedError.new("Crystal::WasiEventLoop.create_fd_write_event")
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    raise NotImplementedError.new("Crystal::WasiEventLoop.create_fd_read_event")
  end
end

struct Crystal::WasiEvent < Crystal::Event
  def add(timeout : Time::Span?) : Nil
  end

  def free : Nil
  end

  def delete
  end
end
