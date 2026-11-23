require "c/poll"

# :nodoc:
# Uses synchronous I/O until WASI supports switching fibers.
# Non-blocking sockets wait synchronously for readiness and support timeouts.
class Crystal::EventLoop::Wasi < Crystal::EventLoop
  def self.default_file_blocking?
    true
  end

  def self.default_socket_blocking?
    false
  end

  def initialize(parallelism : Int32)
  end

  # Runs the event loop.
  def run(blocking : Bool) : Bool
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.run")
  end

  def interrupt : Nil
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.interrupt")
  end

  def sleep(duration : ::Time::Span) : Nil
    # block the single thread until we support fiber swapcontext
    System::Thread.sleep(duration)
  end

  # Creates a timeout_event.
  def create_timeout_event(fiber) : Crystal::EventLoop::Event
    raise NotImplementedError.new("Crystal::Wasi::EventLoop.create_timeout_event")
  end

  def pipe(read_blocking : Bool?, write_blocking : Bool?) : {IO::FileDescriptor, IO::FileDescriptor}
    {% if flag?(:wasip1) || flag?(:wasip2) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#pipe")
    {% else %}
      r, w = System::FileDescriptor.system_pipe
      # Default to blocking until the event loop supports waiting for pipe I/O.
      System::FileDescriptor.set_blocking(r, false) if read_blocking == false
      System::FileDescriptor.set_blocking(w, false) if write_blocking == false
      {
        IO::FileDescriptor.new(handle: r),
        IO::FileDescriptor.new(handle: w),
      }
    {% end %}
  end

  def open(path : String, flags : Int32, permissions : File::Permissions, blocking : Bool?) : {System::FileDescriptor::Handle, Bool} | Errno | WinError
    fd = LibC.open(path.check_no_null_byte, flags, permissions)
    return Errno.value if fd == -1

    # WASI filesystem descriptors are always blocking
    {fd, true}
  end

  def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    loop do
      bytes_read = LibC.read(file_descriptor.fd, slice, slice.size)
      return bytes_read.to_i32 unless bytes_read == -1

      case errno = Errno.value
      when Errno::EBADF
        raise IO::Error.new "File not open for reading", target: file_descriptor
      when Errno::EINTR
        next
      else
        raise IO::Error.from_os_error("Error reading file_descriptor", errno, target: file_descriptor)
      end
    end
  end

  def pread(file_descriptor : System::FileDescriptor, slice : Bytes, offset : Int64) : Int32
    loop do
      bytes_read = LibC.pread(file_descriptor.fd, slice, slice.size, offset)
      return bytes_read.to_i32 unless bytes_read == -1

      unless Errno.value == Errno::EINTR
        raise IO::Error.from_errno("Error reading file_descriptor", target: file_descriptor)
      end
    end
  end

  def wait_readable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    raise NotImplementedError.new("Crystal::EventLoop::Wasi#wait_readable")
  end

  def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    loop do
      bytes_written = LibC.write(file_descriptor.fd, slice, slice.size)
      return bytes_written.to_i32 unless bytes_written == -1

      {% begin %}
      case errno = Errno.value
      when Errno::EBADF
        raise IO::Error.new "File not open for writing", target: file_descriptor
      {% if flag?(:wasip2) %}
      # wasi-libc preview 2 reports EIO for writes to read-only files.
      when Errno::EIO
        flags = LibC.fcntl(file_descriptor.fd, LibC::F_GETFL)
        if flags != -1 && (flags & LibC::O_RDWR) == LibC::O_RDONLY
          raise IO::Error.new "File not open for writing", target: file_descriptor
        end
      {% end %}
      when Errno::EINTR
        next
      else
        raise IO::Error.from_os_error("Error writing file_descriptor", errno, target: file_descriptor)
      end
      {% end %}
    end
  end

  def wait_writable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    raise NotImplementedError.new("Crystal::EventLoop::Wasi#wait_writable")
  end

  def reopened(file_descriptor : Crystal::System::FileDescriptor) : Nil
    # No events to update until the event loop supports waiting for file I/O.
  end

  def shutdown(file_descriptor : Crystal::System::FileDescriptor) : Nil
    # No pending fiber operations to cancel.
  end

  def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
    file_descriptor.file_descriptor_close
  end

  def socket(family : ::Socket::Family, type : ::Socket::Type, protocol : ::Socket::Protocol, blocking : Bool | ::Nil) : {::Socket::Handle, Bool}
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#socket requires wasip2 or later")
    {% else %}
      raise NotImplementedError.new("WASI doesn't implement UNIX sockets") if family.unix?

      blocking = Wasi.default_socket_blocking? if blocking.nil?
      flags = type.value | LibC::SOCK_CLOEXEC
      flags |= LibC::SOCK_NONBLOCK unless blocking

      fd = LibC.socket(family, flags, protocol)
      raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1

      {fd, blocking}
    {% end %}
  end

  def socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : Tuple({::Socket::Handle, ::Socket::Handle}, Bool)
    raise NotImplementedError.new("Crystal::EventLoop::Wasi#socketpair")
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    deadline = to_deadline(socket.read_timeout)
    loop do
      bytes_read = LibC.recv(socket.fd, slice, slice.size, 0)
      return bytes_read.to_i32 unless bytes_read == -1

      case errno = Errno.value
      when Errno::EAGAIN
        wait(socket, LibC::POLLIN, deadline) do
          raise IO::TimeoutError.new("Read timed out", target: socket)
        end
      when Errno::EINTR
        next
      else
        raise IO::Error.from_os_error("Error reading socket", errno, target: socket)
      end
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    wait(socket, LibC::POLLIN, to_deadline(socket.read_timeout)) do
      raise IO::TimeoutError.new("Read timed out", target: socket)
    end
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    deadline = to_deadline(socket.write_timeout)
    loop do
      bytes_written = LibC.send(socket.fd, slice, slice.size, 0)
      return bytes_written.to_i32 unless bytes_written == -1

      case errno = Errno.value
      when Errno::EAGAIN
        wait(socket, LibC::POLLOUT, deadline) do
          raise IO::TimeoutError.new("Write timed out", target: socket)
        end
      when Errno::EINTR
        next
      else
        raise IO::Error.from_os_error("Error writing to socket", errno, target: socket)
      end
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    wait(socket, LibC::POLLOUT, to_deadline(socket.write_timeout)) do
      raise IO::TimeoutError.new("Write timed out", target: socket)
    end
  end

  def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#receive_from requires wasip2 or later")
    {% else %}
      sockaddr = LibC::SockaddrStorage.new
      sockaddr.ss_family = socket.family.value
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))
      deadline = to_deadline(socket.read_timeout)

      loop do
        bytes_read = LibC.recvfrom(socket.fd, slice, slice.size, 0, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen))

        unless bytes_read == -1
          return {bytes_read.to_i32, ::Socket::IPAddress.from(pointerof(sockaddr).as(LibC::Sockaddr*), addrlen)}
        end

        case errno = Errno.value
        when Errno::EAGAIN
          wait(socket, LibC::POLLIN, deadline) do
            raise IO::TimeoutError.new("Read timed out", target: socket)
          end
        when Errno::EINTR
          next
        else
          raise IO::Error.from_os_error("Error receiving datagram", errno, target: socket)
        end
      end
    {% end %}
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#send_to requires wasip2 or later")
    {% else %}
      deadline = to_deadline(socket.write_timeout)
      loop do
        bytes_sent = LibC.sendto(socket.fd, slice, slice.size, 0, address, address.size)
        return bytes_sent.to_i32 unless bytes_sent == -1

        case errno = Errno.value
        when Errno::EAGAIN
          wait(socket, LibC::POLLOUT, deadline) do
            raise IO::TimeoutError.new("Write timed out", target: socket)
          end
        when Errno::EINTR
          next
        else
          raise IO::Error.from_os_error("Error sending datagram to #{address}", errno, target: socket)
        end
      end
    {% end %}
  end

  def connect(socket : ::Socket, address : ::Socket::UNIXAddress, timeout : ::Time::Span | ::Nil) : IO::Error?
    raise NotImplementedError.new("WASI doesn't support UNIX sockets")
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : ::Time::Span | ::Nil) : IO::Error?
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#connect requires wasip2 or later")
    {% else %}
      return if LibC.connect(socket.fd, address, address.size) == 0

      errno = Errno.value
      deadline = to_deadline(timeout)

      loop do
        case errno
        when Errno::EINPROGRESS, Errno::EALREADY, Errno::EINTR
          wait(socket, LibC::POLLOUT, deadline) do
            return IO::TimeoutError.new("connect timed out", target: socket)
          end

          error = 0
          size = LibC::SocklenT.new(sizeof(Int32))
          if LibC.getsockopt(socket.fd, LibC::SOL_SOCKET, LibC::SO_ERROR, pointerof(error), pointerof(size)) == -1
            return ::Socket::ConnectError.from_errno("connect")
          end
          return if error == 0
          errno = Errno.new(error)
        else
          return ::Socket::ConnectError.from_os_error("connect", errno)
        end
      end
    {% end %}
  end

  def accept(socket : ::Socket) : {::Socket::Handle, Bool}?
    return if socket.closed?

    deadline = to_deadline(socket.read_timeout)
    blocking = System::Socket.get_blocking(socket.fd)
    flags = LibC::SOCK_CLOEXEC
    flags |= LibC::SOCK_NONBLOCK unless blocking

    loop do
      return if socket.closed?

      client_fd = LibC.accept4(socket.fd, nil, nil, flags)
      return {client_fd, blocking} unless client_fd == -1

      case errno = Errno.value
      when Errno::EAGAIN
        wait(socket, LibC::POLLIN, deadline) do
          raise IO::TimeoutError.new("Accept timed out", target: socket)
        end
      when Errno::EINTR
        next
      else
        raise ::Socket::Error.from_os_error("accept", errno)
      end
    end
  end

  def sendfile(socket : ::Socket, fd : System::FileDescriptor::Handle, offset : Int64, count : Int64, flags : Int32) : Int64 | Errno | WinError
    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]
    deadline = to_deadline(socket.write_timeout)

    loop do
      bytes_read = LibC.pread(fd, buffer, count.clamp(..buffer.size), offset)

      if bytes_read == -1
        next if Errno.value == Errno::EINTR
        return Errno.value
      end

      slice = buffer.to_slice[0, bytes_read]
      until slice.empty?
        bytes_sent = LibC.send(socket.fd, slice, slice.size, 0)

        if bytes_sent == -1
          case errno = Errno.value
          when Errno::EAGAIN
            wait(socket, LibC::POLLOUT, deadline) { return Errno::ETIMEDOUT }
          when Errno::EINTR
            next
          else
            return errno
          end
        else
          slice += bytes_sent
        end
      end

      return bytes_read.to_i64
    end
  end

  def shutdown(socket : ::Socket) : Nil
    # No pending fiber operations to cancel.
  end

  def close(socket : ::Socket) : Nil
    socket.socket_close
  end

  private def wait(socket : ::Socket, events, deadline : Time::Instant?, &) : Nil
    pollfd = LibC::Pollfd.new(fd: socket.fd, events: events)

    loop do
      raise IO::Error.new("Closed stream", target: socket) if socket.closed?

      milliseconds =
        if deadline
          remaining = deadline - Time.instant
          remaining.total_milliseconds.ceil.clamp(0, Int32::MAX).to_i
        else
          -1
        end

      ret = LibC.poll(pointerof(pollfd), 1, milliseconds)
      if ret > 0
        if pollfd.revents & LibC::POLLNVAL != 0
          raise IO::Error.new("Closed stream", target: socket)
        end
        return
      end

      if ret == 0
        next if deadline && Time.instant < deadline
        yield
        return
      end

      unless Errno.value == Errno::EINTR
        raise IO::Error.from_errno("poll", target: socket)
      end
    end
  end

  private def to_deadline(timeout : Time::Span?)
    Time.instant + timeout if timeout
  end
end

struct Crystal::EventLoop::Wasi::Event
  include Crystal::EventLoop::Event

  def add(timeout : Time::Span, timeout_select_action : Channel::TimeoutAction? = nil) : Nil
  end

  def add(timeout : Nil) : Nil
  end

  def free : Nil
  end

  def delete
  end
end
