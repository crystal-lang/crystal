# :nodoc:
# Uses blocking I/O until WASI supports switching fibers.
# I/O timeouts and readiness waits are not supported.
class Crystal::EventLoop::Wasi < Crystal::EventLoop
  def self.default_file_blocking?
    true
  end

  def self.default_socket_blocking?
    true
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
    loop do
      bytes_read = LibC.recv(socket.fd, slice, slice.size, 0)
      return bytes_read.to_i32 unless bytes_read == -1

      unless Errno.value == Errno::EINTR
        raise IO::Error.from_errno("Error reading socket", target: socket)
      end
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    raise NotImplementedError.new("Crystal::EventLoop::Wasi#wait_readable")
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    loop do
      bytes_written = LibC.send(socket.fd, slice, slice.size, 0)
      return bytes_written.to_i32 unless bytes_written == -1

      unless Errno.value == Errno::EINTR
        raise IO::Error.from_errno("Error writing to socket", target: socket)
      end
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    raise NotImplementedError.new("Crystal::EventLoop::Wasi#wait_writable")
  end

  def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#receive_from requires wasip2 or later")
    {% else %}
      sockaddr = LibC::SockaddrStorage.new
      sockaddr.ss_family = socket.family.value
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

      loop do
        bytes_read = LibC.recvfrom(socket.fd, slice, slice.size, 0, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen))

        unless bytes_read == -1
          return {bytes_read.to_i32, ::Socket::IPAddress.from(pointerof(sockaddr).as(LibC::Sockaddr*), addrlen)}
        end

        unless Errno.value == Errno::EINTR
          raise IO::Error.from_errno("Error receiving datagram", target: socket)
        end
      end
    {% end %}
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    {% if flag?(:wasip1) %}
      raise NotImplementedError.new("Crystal::EventLoop::Wasi#send_to requires wasip2 or later")
    {% else %}
      loop do
        bytes_sent = LibC.sendto(socket.fd, slice, slice.size, 0, address, address.size)
        return bytes_sent.to_i32 unless bytes_sent == -1

        unless Errno.value == Errno::EINTR
          raise IO::Error.from_errno("Error sending datagram to #{address}", target: socket)
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
      loop do
        return if LibC.connect(socket.fd, address, address.size) == 0

        unless Errno.value == Errno::EINTR
          return ::Socket::ConnectError.from_errno("connect")
        end
      end
    {% end %}
  end

  def accept(socket : ::Socket) : {::Socket::Handle, Bool}?
    loop do
      return if socket.closed?

      client_fd = LibC.accept4(socket.fd, nil, nil, LibC::SOCK_CLOEXEC)
      return {client_fd, true} unless client_fd == -1

      unless Errno.value == Errno::EINTR
        raise ::Socket::Error.from_errno("accept")
      end
    end
  end

  def sendfile(socket : ::Socket, fd : System::FileDescriptor::Handle, offset : Int64, count : Int64, flags : Int32) : Int64 | Errno | WinError
    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]

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
          return Errno.value unless Errno.value == Errno::EINTR
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
