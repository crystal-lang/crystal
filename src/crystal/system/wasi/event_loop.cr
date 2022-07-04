# :nodoc:
module Crystal::EventLoop
  # Runs the event loop.
  def self.run_once
    raise NotImplementedError.new("Crystal::EventLoop.run_once")
  end

  # Create a new resume event for a fiber.
  def self.create_resume_event(fiber : Fiber) : Crystal::Event
    raise NotImplementedError.new("Crystal::EventLoop.create_resume_event")
  end

  # Creates a timeout_event.
  def self.create_timeout_event(fiber) : Crystal::Event
    raise NotImplementedError.new("Crystal::EventLoop.create_timeout_event")
  end

  # Creates a write event for a file descriptor.
  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    raise NotImplementedError.new("Crystal::EventLoop.create_fd_write_event")
  end

  # Creates a read event for a file descriptor.
  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    raise NotImplementedError.new("Crystal::EventLoop.create_fd_read_event")
  end
end

struct Crystal::Event
  def add(timeout : LibC::Timeval? = nil)
  end

  def add(timeout : Time::Span)
  end

  def free
  end

  def delete
  end
end
