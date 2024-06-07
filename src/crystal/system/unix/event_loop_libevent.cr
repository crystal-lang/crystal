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

  def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = socket.family
    sockaddr.value = copy

    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    bytes_read = socket.evented_read("Error receiving datagram") do
      LibC.recvfrom(socket.fd, slice, slice.size, 0, sockaddr, pointerof(addrlen))
    end

    {bytes_read, ::Socket::Address.from(sockaddr, addrlen)}
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    bytes_sent = LibC.sendto(socket.fd, slice.to_unsafe.as(Void*), slice.size, 0, address, address.size)
    raise ::Socket::Error.from_errno("Error sending datagram to #{address}") if bytes_sent == -1
    # to_i32 is fine because string/slice sizes are an Int32
    bytes_sent.to_i32
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
      client_fd =
        {% if LibC.has_method?(:accept4) %}
          LibC.accept4(socket.fd, nil, nil, LibC::SOCK_CLOEXEC)
        {% else %}
          LibC.accept(socket.fd, nil, nil)
        {% end %}

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
        {% unless LibC.has_method?(:accept4) %}
          Crystal::System::Socket.fcntl(client_fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
        {% end %}
        return client_fd
      end
    end
  end

  def close(socket : ::Socket) : Nil
    socket.evented_close
  end
end
