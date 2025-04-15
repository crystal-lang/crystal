require "./libevent/event"

# :nodoc:
class Crystal::EventLoop::LibEvent < Crystal::EventLoop
  def self.default_blocking : Bool
    false
  end

  private getter(event_base) { Crystal::EventLoop::LibEvent::Event::Base.new }

  def after_fork_before_exec : Nil
  end

  {% unless flag?(:preview_mt) %}
    # Reinitializes the event loop after a fork.
    def after_fork : Nil
      event_base.reinit
    end
  {% end %}

  def run(blocking : Bool) : Bool
    flags = LibEvent2::EventLoopFlags::Once
    flags |= blocking ? LibEvent2::EventLoopFlags::NoExitOnEmpty : LibEvent2::EventLoopFlags::NonBlock
    event_base.loop(flags)
  end

  {% if flag?(:execution_context) %}
    def run(queue : Fiber::List*, blocking : Bool) : Nil
      Crystal.trace :evloop, "run", fiber: fiber, blocking: blocking
      @runnables = queue
      run(blocking)
    ensure
      @runnables = nil
    end

    def callback_enqueue(fiber : Fiber) : Nil
      if queue = @runnables
        queue.value.push(fiber)
      else
        raise "BUG: libevent callback executed outside of #run(queue*, blocking) call"
      end
    end
  {% end %}

  def interrupt : Nil
    event_base.loop_exit
  end

  def sleep(duration : ::Time::Span) : Nil
    Fiber.current.resume_event.add(duration)
    Fiber.suspend
  end

  # Create a new resume event for a fiber (sleep).
  def create_resume_event(fiber : Fiber) : Crystal::EventLoop::LibEvent::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      f = data.as(Fiber)
      {% if flag?(:execution_context) %}
        event_loop = Crystal::EventLoop.current.as(Crystal::EventLoop::LibEvent)
        event_loop.callback_enqueue(f)
      {% else %}
        f.enqueue
      {% end %}
    end
  end

  # Creates a timeout event (timeout action of select expression).
  def create_timeout_event(fiber) : Crystal::EventLoop::LibEvent::Event
    event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
      f = data.as(Fiber)
      if select_action = f.timeout_select_action
        f.timeout_select_action = nil
        if select_action.time_expired?
          {% if flag?(:execution_context) %}
            event_loop = Crystal::EventLoop.current.as(Crystal::EventLoop::LibEvent)
            event_loop.callback_enqueue(f)
          {% else %}
            f.enqueue
          {% end %}
        end
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

  def open(filename : String, flags : Int32, permissions : File::Permissions, blocking : Bool?) : System::FileDescriptor::Handle | Errno
    filename.check_no_null_byte

    fd = 0
    flags |= LibC::O_CLOEXEC

    # We can't reliably detect without significant overhead whether *filename*
    # might block for a while before calling open; while O_NONBLOCK has no
    # effect on regular disk files, special file types are a different story.
    # Open with O_NONBLOCK will fail with ENXIO for O_WRONLY (no connected
    # reader) but it will always succeed for O_RDONLY (regardless of a connected
    # writer or not), then any attempt to read will return EOF, leaving no means
    # to wait until a writer connects.
    #
    # We thus rely on the *blocking* arg: when false the file might be a special
    # file type, so we check it; if it's a fifo (named pipe) or a character
    # device, we open in another thread so we don't risk blocking the current
    # thread (and thus other fibers) until a reader or writer is also connected.
    #
    # We need preview_mt to safely re-enqueue the current fiber from the thread.
    {% if flag?(:preview_mt) && !flag?(:interpreted) %}
      if !blocking && System::File.special_file_type?(filename)
        fd, errno = System::File.async_open(filename, flags, permissions)
        return errno if fd == -1
      else
        fd = LibC.open(filename, flags, permissions)
        return Errno.value if fd == -1
      end
    {% else %}
      fd = LibC.open(filename, flags, permissions)
      return Errno.value if fd == -1
    {% end %}

    # Always set O_NONBLOCK (it's a requirement).
    status_flags = System::FileDescriptor.fcntl(fd, LibC::F_GETFL)
    System::FileDescriptor.fcntl(fd, LibC::F_SETFL, status_flags | LibC::O_NONBLOCK)

    fd
  end

  def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    evented_read(file_descriptor, "Error reading file_descriptor") do
      LibC.read(file_descriptor.fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for reading", target: file_descriptor
        end
      end
    end
  end

  def wait_readable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.evented_wait_readable(raise_if_closed: false) do
      raise IO::TimeoutError.new("Read timed out")
    end
  end

  def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    evented_write(file_descriptor, "Error writing file_descriptor") do
      LibC.write(file_descriptor.fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing", target: file_descriptor
        end
      end
    end
  end

  def wait_writable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.evented_wait_writable do
      raise IO::TimeoutError.new("Write timed out")
    end
  end

  def reopened(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.evented_close
  end

  def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.evented_close
  end

  def socket(family : ::Socket::Family, type : ::Socket::Type, protocol : ::Socket::Protocol) : System::Socket::Handle
    {% if LibC.has_constant?(:SOCK_CLOEXEC) %}
      fd = LibC.socket(family, type.value | LibC::SOCK_CLOEXEC | LibC::SOCK_NONBLOCK, protocol)
      raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
      fd
    {% else %}
      Process.lock_read do
        fd = LibC.socket(family, type, protocol)
        raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
        System::Socket.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
        System::Socket.fcntl(fd, LibC::F_SETFL, System::Socket.fcntl(LibC::F_GETFL) | LibC::O_NONBLOCK)
        fd
      end
    {% end %}
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    evented_read(socket, "Error reading socket") do
      LibC.recv(socket.fd, slice, slice.size, 0).to_i32
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    socket.evented_wait_readable(raise_if_closed: false) do
      raise IO::TimeoutError.new("Read timed out")
    end
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    evented_write(socket, "Error writing to socket") do
      LibC.send(socket.fd, slice, slice.size, 0).to_i32
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    socket.evented_wait_writable do
      raise IO::TimeoutError.new("Write timed out")
    end
  end

  def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = socket.family
    sockaddr.value = copy

    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    bytes_read = evented_read(socket, "Error receiving datagram") do
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
        socket.evented_wait_writable(timeout: timeout) do
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
          # we may fail to set FD_CLOEXEC between `accept` and `fcntl` but we
          # can't call `Crystal::System::Socket.lock_read` because the socket
          # might be in blocking mode and accept would block until the socket
          # receives a connection.
          #
          # we could lock when `socket.blocking?` is false, but another thread
          # could change the socket back to blocking mode between the condition
          # check and the `accept` call.
          fd = LibC.accept(socket.fd, nil, nil)
          Crystal::System::Socket.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC) unless fd == -1
          fd
        {% end %}

      if client_fd == -1
        if socket.closed?
          return
        elsif Errno.value == Errno::EAGAIN
          socket.evented_wait_readable(raise_if_closed: false) do
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

  def evented_read(target, errno_msg : String, &) : Int32
    loop do
      bytes_read = yield
      if bytes_read != -1
        # `to_i32` is acceptable because `Slice#size` is an Int32
        return bytes_read.to_i32
      end

      if Errno.value == Errno::EAGAIN
        target.evented_wait_readable do
          raise IO::TimeoutError.new("Read timed out")
        end
      else
        raise IO::Error.from_errno(errno_msg, target: target)
      end
    end
  ensure
    target.evented_resume_pending_readers
  end

  def evented_write(target, errno_msg : String, &) : Int32
    begin
      loop do
        bytes_written = yield
        if bytes_written != -1
          return bytes_written.to_i32
        end

        if Errno.value == Errno::EAGAIN
          target.evented_wait_writable do
            raise IO::TimeoutError.new("Write timed out")
          end
        else
          raise IO::Error.from_errno(errno_msg, target: target)
        end
      end
    ensure
      target.evented_resume_pending_writers
    end
  end
end
