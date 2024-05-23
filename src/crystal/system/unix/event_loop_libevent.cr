require "./event_libevent"

# :nodoc:
abstract class Crystal::EventLoop
  def self.create
    Crystal::LibEvent::EventLoop.new
  end
end

# :nodoc:
class Crystal::LibEvent::EventLoop < Crystal::EventLoop
  private getter(event_base) { Crystal::LibEvent::Event::Base.new }

  {% unless flag?(:preview_mt) %}
    # Reinitializes the event loop after a fork.
    def after_fork : Nil
      event_base.reinit
    end
  {% end %}

  def run(blocking : Bool) : Bool
    event_base.loop(once: true, nonblock: !blocking)
  end

  def interrupt : Nil
    event_base.loop_exit
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::EventLoop::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      data.as(Fiber).enqueue
    end
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : Crystal::EventLoop::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      f = data.as(Fiber)
      if (select_action = f.timeout_select_action)
        f.timeout_select_action = nil
        select_action.time_expired(f)
      else
        f.enqueue
      end
    end
  end

  # Creates a write event for a file descriptor.
  def create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::EventLoop::Event
    flags = LibEvent2::EventFlags::Write
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Write)
        io_ref.resume_write
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_write(timed_out: true)
      end
    end
  end

  # Creates a read event for a file descriptor.
  def create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::EventLoop::Event
    flags = LibEvent2::EventFlags::Read
    flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

    event_base.new_event(io.fd, flags, io) do |s, flags, data|
      io_ref = data.as(typeof(io))
      if flags.includes?(LibEvent2::EventFlags::Read)
        io_ref.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Timeout)
        io_ref.resume_read(timed_out: true)
      end
    end
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    socket.evented_read("Error reading socket") do
      LibC.recv(socket.fd, slice, slice.size, 0).to_i32
    end
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    socket.evented_write("Error writing to socket") do
      LibC.send(socket.fd, slice, slice.size, 0).to_i32
    end
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : ::Time::Span?) : IO::Error?
    loop do
      if LibC.connect(socket.fd, address, address.size) == 0
        return
      end
      case Errno.value
      when Errno::EISCONN
        return
      when Errno::EINPROGRESS, Errno::EALREADY
        socket.wait_writable(timeout: timeout) do
          return IO::TimeoutError.new("connect timed out")
        end
      else
        return ::Socket::ConnectError.from_errno("connect")
      end
    end
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
    loop do
      client_fd = LibC.accept(socket.fd, nil, nil)
      if client_fd == -1
        if socket.closed?
          return
        elsif Errno.value == Errno::EAGAIN
          socket.wait_readable(raise_if_closed: false) do
            raise IO::TimeoutError.new("Accept timed out")
          end
          return if socket.closed?
        else
          raise ::Socket::Error.from_errno("accept")
        end
      else
        return client_fd
      end
    end
  end

  def close(socket : ::Socket) : Nil
    socket.evented_close
  end
end
