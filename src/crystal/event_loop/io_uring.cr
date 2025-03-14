# forward declaration for the require below to not create a module
class Crystal::EventLoop::IoUring < Crystal::EventLoop
end

require "../system/unix/epoll"
require "../system/unix/eventfd"
require "../system/unix/io_uring"
require "../system/unix/timerfd"
require "./timers"
require "./io_uring/*"

class Crystal::EventLoop::IoUring < Crystal::EventLoop
  class_getter(supported : Bool) do
    System::IoUring.supported? &&
      System::IoUring.supports_feature?(LibC::IORING_FEAT_NODROP) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_READ) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_WRITE) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_CONNECT) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_ACCEPT) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_LINK_TIMEOUT)
  end

  def initialize
    @lock = SpinLock.new
    # @timers = Timers(Event).new

    # epoll instance to wait on
    @epoll = System::Epoll.new

    # the actual ring, notifies epoll through eventfd
    @ring = System::IoUring.new(
      sq_entries: 16,
      cq_entries: 128,
      sq_idle: (2000 if System::IoUring.supports_feature?(LibC::IORING_FEAT_SQPOLL_NONFIXED))
    )
    @ring.register(System::EventFD.new)
    @epoll.add(@ring.eventfd.fd, LibC::EPOLLIN, u64: @ring.eventfd.fd.to_u64!)

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    @eventfd = System::EventFD.new
    @epoll.add(@eventfd.fd, LibC::EPOLLIN, u64: @eventfd.fd.to_u64!)

    # we use timerfd to go below the millisecond precision of epoll_wait; it
    # also allows to avoid locking timers before every epoll_wait call
    @timerfd = System::TimerFD.new
    @epoll.add(@timerfd.fd, LibC::EPOLLIN, u64: @timerfd.fd.to_u64!)
  end

  def after_fork_before_exec : Nil
    @lock = SpinLock.new
    @ring.close
    @epoll.close
    @eventfd.close
    @timerfd.close
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      raise NotImplementedError.new("Crystal::EventLoop::IoUring#after_fork isn't implemented")
    end
  {% end %}

  def run(blocking : Bool) : Bool
    system_run(blocking, &.enqueue)
  end

  {% if flag?(:execution_context) %}
    def run(queue : Fiber::List*, blocking : Bool) : Bool
      system_run(blocking) { |fiber| queue.value.push(fiber) }
    end
  {% end %}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    Crystal.trace :evloop, "run", blocking: blocking

    # wait for events (indefinitely when blocking)
    buffer = uninitialized LibC::EpollEvent[4]
    epoll_events = @epoll.wait(buffer.to_slice, timeout: blocking ? -1 : 0)

    # process events
    epoll_events.size.times do |i|
      epoll_event = epoll_events.to_unsafe + i
      # TODO: panic if epoll_event.value.events != LibC::EPOLLIN (could be EPOLLERR or EPOLLHUP)

      case epoll_event.value.data.u64
      when @timerfd.fd
        Crystal.trace :evloop, "timer"
        # process_timers { |fiber| yield fiber }
      when @eventfd.fd
        Crystal.trace :evloop, "interrupted"
        @eventfd.read
        @interrupted.clear
      else
        process_cqes(@ring)
      end
    end
  end

  private def process_cqes
    @ring.each_completed do |cqe|
      if event = Pointer(Event).new(cqe.value.user_data)
        event.res = cqe.value.res
        yield event.value.fiber
      end
    end
  end

  # private def process_timers : Nil
  # end

  # private def process_timer(event : Event*, &)
  # end

  def interrupt : Nil
    # the atomic makes sure we only write once (no need to write multiple times)
    @eventfd.write(1) if @interrupted.test_and_set
  end

  # fiber interface, see Crystal::EventLoop

  def create_resume_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(:sleep, fiber)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(:select_timeout, fiber)
  end

  # file descriptor interface, see Crystal::EventLoop::FileDescriptor

  def read(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_READ, file_descriptor.fd, slice, file_descriptor.@read_timeout) do |errno|
      case errno
      when Errno::ECANCELLED
        raise IO::TimeoutError.new("Read timed out")
      when Errno::EBADF
        raise IO::Error.new("File not open for reading", target: file_descriptor)
      else
        raise IO::Error.from_os_error("read", errno, target: file_descriptor)
      end
    end
  end

  def wait_readable(file_descriptor : System::FileDescriptor) : Nil
    async_poll(file_descriptor.fd, LibC::POLLOUT, file_descriptor.@read_timeout) { "Read timed out" }
  end

  def write(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, file_descriptor.fd, slice, file_descriptor.@write_timeout) do |errno|
      case errno
      when Errno::ECANCELLED
        raise IO::TimeoutError.new("Write timed out")
      when Errno::EBADF
        raise IO::Error.new("File not open for writing", target: file_descriptor)
      else
        raise IO::Error.from_os_error("write", errno, target: file_descriptor)
      end
    end
  end

  def wait_writable(file_descriptor : System::FileDescriptor) : Nil
    async_poll(file_descriptor.fd, LibC::POLLOUT, file_descriptor.@write_timeout) { "Write timed out" }
  end

  def close(file_descriptor : System::FileDescriptor) : Nil
    # TODO: async close
  end

  # socket interface, see Crystal::EventLoop::Socket

  def read(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_READ, socket.fd, slice, socket.@read_timeout) do |errno|
      case errno
      when Errno::ECANCELLED
        raise IO::TimeoutError.new("Read timed out")
      else
        raise IO::Error.from_os_error("read", errno, target: file_descriptor)
      end
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    async_poll(socket.fd, LibC::POLLOUT, socket.@read_timeout) { "Read timed out" }
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, socket.fd, slice, socket.@write_timeout) do |errno|
      case errno
      when Errno::ECANCELLED
        raise IO::TimeoutError.new("Write timed out")
      else
        raise IO::Error.from_os_error("write", errno, target: file_descriptor)
      end
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    async_poll(socket.fd, LibC::POLLOUT, socket.@write_timeout) { "Write timed out" }
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
    ret = async(LibC::IORING_OP_ACCEPT) do |sqe|
      sqe.value.fd = sock.fd
      sqe.value.sflags.accept_flags = LibC::SOCK_CLOEXEC
      sqe.value.user_data = pointerof(event)
    end
    return ret unless ret < 0

    if ret == -LibC::ECANCELLED
      raise IO::TimeoutError.new("Accept timed out")
    elsif !socket.closed?
      raise ::Socket::Error.from_os_error("accept", Errno.new(-ret))
    end
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : Time::Span?) : IO::Error?
    sockaddr = address.to_unsafe
    addrlen = address.size

    ret = async(LibC::IORING_OP_CONNECT, timeout) do |sqe|
      sqe.value.fd = sock.fd
      sqe.value.addr = sockaddr.address.to_u64!
      sqe.value.u1.off = addrlen.to_u64!
      sqe.value.user_data = pointerof(event)
    end
    return if ret == 0

    if ret == -LibC::ECANCELLED
      IO::TimeoutError.new("Connect timed out")
    elsif ret != -LibC::EISCONN
      ::Socket::ConnectError.from_os_error("connect", Errno.new(-ret))
    end
  end

  @@supports_sendto = supports_opcode?(LibC::IORING_OP_SEND)

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    sockaddr = address.to_unsafe
    addrlen = address.size

    if @@supports_sendto
      ret = async(LibC::IORING_OP_SEND) do |sqe|
        sqe.value.fd = sock.fd
        sqe.value.addr = slice.to_unsafe.address.to_u64!
        sqe.value.len = slice.size.to_u64!
        sqe.value.u1.addr2 = sockaddr.address.to_u64!
        sqe.value.addr_len[0] = addrlen.to_u16!
        sqe.value.user_data = pointerof(event)
      end
      return ret unless ret < 0
      raise ::Socket::Error.from_os_error("Error sending datagram to #{address}", Errno.new(-ret)) unless ret == -LibC::EINVAL
      @@supports_sendto = false
    end

    ret = LibC.sendto(socket.fd, slice.to_unsafe.as(Void*), slice.size, 0, sockaddr, addrlen)
    raise ::Socket::Error.from_errno("Error sending datagram to #{address}") if ret == -1
    ret
  end

  def receive_from(socket : ::Socket, slice : Bytes) : {Int32, ::Socket::Address}
    sockaddr = LibC::SockaddrStorage.new
    sockaddr.sa_family = socket.family
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    loop do
      ret = LibC.recvfrom(socket.fd, slice, slice.size, 0, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen))
      if ret == -1
        if Errno.value == Errno::EAGAIN
          wait_readable(socket)
          raise IO::Error.new("Closed stream") if socket.closed?
        else
          raise IO::Error.from_errno("recvfrom", target: socket)
        end
      else
        return {ret, ::Socket::Address.from(pointerof(sockaddr), addrlen)}
      end
    end
  end

  def close(socket : ::Socket) : Nil
    # TODO: async close
  end

  # internals

  private def async_rw(opcode, fd, slice, timeout, &)
    res = async(opcode, timeout) do
      sqe.value.fd = fd
      sqe.value.u1.off = -1
      sqe.value.addr = slice.to_unsafe.address.to_u64!
      sqe.value.len = slice.size
    end

    if res < 0
      yield Errno.new(-res)
    else
      res
    end
  end

  private def async_poll(fd, poll_events, timeout)
    res = async(LibC::IORING_OP_POLL_ADD, timeout) do |sqe|
      sqe.value.fd = fd
      sqe.value.sflags.poll_events = poll_events | LibC::POLLERR | LibC::POLLHUP
    end
    raise IO::TimeoutError.new(yield) if res == -ECANCELLED
    raise IO::Error.new("Closed stream") if socket.closed?
  end

  private def async(opcode, timeout = nil, &)
    event = Event.new(:async, Fiber.current)
    @ring.prepare(event, opcode, timeout) { |sqe| yield sqe }
    @ring.submit
    Fiber.suspend
    event.res
  end

  private def prepare(event, opcode, timeout, &)
    @ring.prepare do |sqe|
      sqe.value.opcode = opcode
      sqe.value.user_data = event.address.to_u64!
      sqe.value.flags = LibC::IOSQE_IO_LINK if timeout
      yield sqe
    end

    return unless timeout

    @ring.prepare(timeout) do |sqe|
      sqe.value.opcode = LibC::IORING_OP_LINK_TIMEOUT
      sqe.value.flags = LibC::IOSQE_CQE_SKIP_SUCCESS # WARNING: incompatible with IOSQE_IO_DRAIN
    end
  end
end
