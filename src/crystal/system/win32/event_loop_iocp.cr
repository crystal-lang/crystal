require "crystal/system/print_error"

class Crystal::EventLoop
  def create : Crystal::IocpEventLoop
    return IocpEventLoop.new
  end
end

class Crystal::IocpEventLoop < Crystal::EventLoop
  @@queue = Deque(Fiber).new

  # Runs the event loop.
  def run_once : Nil
    next_fiber = @@queue.pop?

    if next_fiber
      Crystal::Scheduler.enqueue next_fiber
    else
      Crystal::System.print_error "Warning: No runnables in scheduler. Exiting program.\n"
      ::exit
    end
  end

  # Reinitializes the event loop after a fork.
  def after_fork : Nil
  end

  def enqueue(fiber : Fiber)
    unless @@queue.includes?(fiber)
      @@queue << fiber
    end
  end

  def dequeue(fiber : Fiber)
    @@queue.delete(fiber)
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::IocpEvent
    enqueue(fiber)

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
  def initialize(@iocp : Crystal::IocpEventLoop, @fiber : Fiber)
  end

  # Frees the event
  def free : Nil
    @iocp.dequeue(@fiber)
  end

  def add(time_span : Time::Span?) : Nil
    @iocp.enqueue(@fiber)
  end
end
