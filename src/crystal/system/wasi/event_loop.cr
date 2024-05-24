# :nodoc:
abstract class Crystal::EventLoop
  def self.create
    Crystal::Wasi::EventLoop.new
  end
end

# :nodoc:
class Crystal::Wasi::EventLoop < Crystal::EventLoop
  # Runs the event loop.
  def run(blocking : Bool) : Bool
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.run")
  end

  def interrupt : Nil
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.interrupt")
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::EventLoop::Event
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.create_resume_event")
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : Crystal::EventLoop::Event
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.create_timeout_event")
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::EventLoop::Event
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.create_fd_write_event")
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::EventLoop::Event
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.create_fd_read_event")
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    socket.evented_read("Error reading socket") do
      LibC.recv(socket.fd, slice, slice.size, 0).to_i32
    end
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    socket.evented_write("Error writing to socket") do
      LibC.send(socket.fd, slice, slice.size, 0)
    end
  end

  def close(socket : ::Socket) : Nil
    socket.evented_close
  end
end

struct Crystal::Wasi::Event
  include Crystal::EventLoop::Event

  def add(timeout : Time::Span?) : Nil
  end

  def free : Nil
  end

  def delete
  end
end
