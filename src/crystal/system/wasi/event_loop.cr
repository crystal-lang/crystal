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

  def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    file_descriptor.evented_read("Error reading file_descriptor") do
      LibC.read(file_descriptor.fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for reading", target: file_descriptor
        end
      end
    end
  end

  def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    file_descriptor.evented_write("Error writing file_descriptor") do
      LibC.write(file_descriptor.fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing", target: file_descriptor
        end
      end
    end
  end

  def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.evented_close
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
