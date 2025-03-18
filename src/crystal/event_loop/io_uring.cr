# forward declaration for the require below to not create a module
class Crystal::EventLoop::IoUring < Crystal::EventLoop
end

require "c/poll"
require "c/sys/socket"
require "../system/unix/io_uring"
require "./io_uring/*"

module Crystal::System::Socket
  # :nodoc:
  property? must_shutdown : Bool = false
end

class Crystal::EventLoop::IoUring < Crystal::EventLoop
  @@supports_sendto = true
  @@supports_close = true

  class_getter?(supported : Bool) do
    if System::IoUring.supported?
      @@supports_sendto = System::IoUring.supports_opcode?(LibC::IORING_OP_SEND)
      @@supports_close = System::IoUring.supports_opcode?(LibC::IORING_OP_SEND)

      System::IoUring.supports_feature?(LibC::IORING_FEAT_NODROP) &&
        System::IoUring.supports_opcode?(LibC::IORING_OP_READ) &&
        System::IoUring.supports_opcode?(LibC::IORING_OP_WRITE) &&
        System::IoUring.supports_opcode?(LibC::IORING_OP_CONNECT) &&
        System::IoUring.supports_opcode?(LibC::IORING_OP_ACCEPT) &&
        System::IoUring.supports_opcode?(LibC::IORING_OP_LINK_TIMEOUT)
    else
      false
    end
  end

  def initialize
    @ring = System::IoUring.new(
      sq_entries: 16,
      cq_entries: 128,
      # sq_idle: (2000 if System::IoUring.supports_feature?(LibC::IORING_FEAT_SQPOLL_NONFIXED))
    )
  end

  def after_fork_before_exec : Nil
    @ring.close
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      raise NotImplementedError.new("Crystal::EventLoop::IoUring#after_fork isn't implemented")
    end
  {% end %}

  def run(blocking : Bool) : Bool
    enqueued = false

    system_run(blocking) do |fiber|
      fiber.enqueue
      enqueued = true
    end

    enqueued
  end

  {% if flag?(:execution_context) %}
    def run(queue : Fiber::List*, blocking : Bool) : Bool
      system_run(blocking) { |fiber| queue.value.push(fiber) }
    end
  {% end %}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    Crystal.trace :evloop, "run", blocking: blocking

    # process ready cqes (avoid syscall)
    size = 0
    process_cqes do |fiber|
      yield fiber
      size += 1
    end

    case size
    when 0
      # empty buffer: ask/wait for completions
      @ring.enter(to_complete: blocking ? 1_u32 : 0_u32, flags: LibC::IORING_ENTER_GETEVENTS)
      process_cqes { |fiber| yield fiber }
    when @ring.@cq_entries.value
      # full buffer: tell kernel that it can report pending completions
      @ring.enter(flags: LibC::IORING_ENTER_GETEVENTS)
      process_cqes { |fiber| yield fiber }
    else
      return
    end
  end

  private def process_cqes(&)
    @ring.each_completed do |cqe|
      # skip CQE for TIMEOUT, TIMEOUT_REMOVE, ...
      next unless event = Pointer(Event).new(cqe.value.user_data)

      fiber = event.value.fiber

      case event.value.type
      when :async
        # nothing to do
      when :sleep
        fiber.@resume_event.as(FiberEvent).clear
      when :select_timeout
        next unless select_action = fiber.timeout_select_action
        fiber.timeout_select_action = nil
        next unless select_action.time_expired?
        fiber.@timeout_event.as(FiberEvent).clear
      end

      event.value.res = cqe.value.res
      # event.flags = cqe.value.flags

      yield fiber
    end
  end

  def interrupt : Nil
    # the atomic makes sure we only write once (no need to write multiple times)
    @eventfd.write(1) if @interrupted.test_and_set
  end

  # timers

  def add_timer(event : Event*) : Nil
    prepare(event, LibC::IORING_OP_TIMEOUT, nil) do |sqe|
      sqe.value.addr = pointerof(event.value.@timespec).address.to_u64!
      sqe.value.len = 1
    end
    @ring.submit
  end

  def delete_timer(event : Event*) : Nil
    @ring.prepare do |sqe|
      sqe.value.opcode = LibC::IORING_OP_TIMEOUT_REMOVE
      sqe.value.flags = LibC::IOSQE_CQE_SKIP_SUCCESS # WARNING: incompatible with IOSQE_IO_DRAIN
      sqe.value.addr = event.address.to_u64!
    end
    @ring.submit
  end

  # fiber interface, see Crystal::EventLoop

  # def sleep(duration : Time::Span) : Nil
  #   res = async_timeout(:sleep, duration)
  #   # assert(res == -ETIME)
  # end

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
      when Errno::ECANCELED
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
    raise IO::Error.new("Closed stream") if file_descriptor.closed?
  end

  def write(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, file_descriptor.fd, slice, file_descriptor.@write_timeout) do |errno|
      case errno
      when Errno::ECANCELED
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
    raise IO::Error.new("Closed stream") if file_descriptor.closed?
  end

  def close(file_descriptor : System::FileDescriptor) : Nil
    # sync with `FileDescriptor#file_descriptor_close`
    fd = file_descriptor.@volatile_fd.swap(-1, :relaxed)
    async_close(fd) unless fd == -1
  end

  # socket interface, see Crystal::EventLoop::Socket

  def read(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_READ, socket.fd, slice, socket.@read_timeout) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Read timed out")
      else
        raise IO::Error.from_os_error("read", errno, target: socket)
      end
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    async_poll(socket.fd, LibC::POLLOUT, socket.@read_timeout) { "Read timed out" }
    raise IO::Error.new("Closed stream") if socket.closed?
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, socket.fd, slice, socket.@write_timeout) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Write timed out")
      else
        raise IO::Error.from_os_error("write", errno, target: socket)
      end
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    async_poll(socket.fd, LibC::POLLOUT, socket.@write_timeout) { "Write timed out" }
    raise IO::Error.new("Closed stream") if socket.closed?
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
    socket.must_shutdown = true

    ret = async(LibC::IORING_OP_ACCEPT, socket.@read_timeout) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.sflags.accept_flags = LibC::SOCK_CLOEXEC
    end
    return ret unless ret < 0

    if ret == -LibC::ECANCELED
      raise IO::TimeoutError.new("Accept timed out")
    elsif !socket.closed?
      raise ::Socket::Error.from_os_error("accept", Errno.new(-ret))
    end
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : Time::Span?) : IO::Error?
    sockaddr = address.to_unsafe # OPTIMIZE: #to_unsafe allocates (not needed)
    addrlen = address.size

    ret = async(LibC::IORING_OP_CONNECT, timeout) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.addr = sockaddr.address.to_u64!
      sqe.value.u1.off = addrlen.to_u64!
    end
    return if ret == 0

    if ret == -LibC::ECANCELED
      IO::TimeoutError.new("Connect timed out")
    elsif ret != -LibC::EISCONN
      ::Socket::ConnectError.from_os_error("connect", Errno.new(-ret))
    end
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    sockaddr = address.to_unsafe # OPTIMIZE: #to_unsafe allocates (not needed)
    addrlen = address.size

    if @@supports_sendto
      ret = async(LibC::IORING_OP_SEND) do |sqe|
        sqe.value.fd = socket.fd
        sqe.value.addr = slice.to_unsafe.address.to_u64!
        sqe.value.len = slice.size.to_u64!
        sqe.value.u1.addr2 = sockaddr.address.to_u64!
        sqe.value.addr_len[0] = addrlen.to_u16!
      end
      return ret unless ret < 0
      raise ::Socket::Error.from_os_error("Error sending datagram to #{address}", Errno.new(-ret)) unless ret == -LibC::EINVAL
      @@supports_sendto = false
    end

    ret = LibC.sendto(socket.fd, slice.to_unsafe.as(Void*), slice.size, 0, sockaddr, addrlen)
    raise ::Socket::Error.from_errno("Error sending datagram to #{address}") if ret == -1
    ret.to_i32
  end

  def receive_from(socket : ::Socket, slice : Bytes) : {Int32, ::Socket::Address}
    sockaddr = LibC::SockaddrStorage.new
    sockaddr.ss_family = socket.family
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
        return {ret.to_i32, ::Socket::Address.from(pointerof(sockaddr).as(LibC::Sockaddr*), addrlen)}
      end
    end
  end

  def close(socket : ::Socket) : Nil
    # sync with `Socket#socket_close`
    fd = socket.@volatile_fd.swap(-1, :relaxed)
    async_close(fd, socket.must_shutdown?) unless fd == -1
  end

  # internals

  private def async_rw(opcode, fd, slice, timeout, &)
    res = async(opcode, timeout) do |sqe|
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
    raise IO::TimeoutError.new(yield) if res == -LibC::ECANCELED
  end

  private def async_close(fd, must_shutdown = false)
    if must_shutdown
      # we must shutdown a socket before closing it, otherwise a pending accept
      # won't be interrupted for example; the shutdown itself isn't attached to
      # an event, receiving a cqe for close is enough
      @ring.prepare do |sqe|
        sqe.value.opcode = LibC::IORING_OP_SHUTDOWN
        sqe.value.flags = LibC::IOSQE_IO_LINK
        sqe.value.flags |= LibC::IOSQE_CQE_SKIP_SUCCESS # WARNING: incompatible with IOSQE_IO_DRAIN
        sqe.value.fd = fd
        sqe.value.len = LibC::SHUT_RDWR
      end
    end

    res = async(LibC::IORING_OP_CLOSE) do |sqe|
      sqe.value.fd = fd
    end

    case res
    when 0
      # success
    when -LibC::EINTR, -LibC::EINPROGRESS
      # ignore
    else
      raise IO::Error.from_os_error("Error closing file", Errno.new(-res))
    end
  end

  private def async_timeout(type, duration, &)
    event = Event.new(type, Fiber.current)

    timespec = LibC::Timespec.new
    timespec.tv_sec = typeof(timespec.tv_sec).new(duration.@seconds)
    timespec.tv_nsec = typeof(timespec.tv_nsec).new(duration.@nanoseconds)

    prepare(pointerof(event), LibC::IORING_OP_TIMEOUT, timeout) do |sqe|
      sqe.value.addr = pointerof(timespec).address.to_u64!
      sqe.value.len = 1
    end
    @ring.submit

    Fiber.suspend
    event.res
  end

  private def async(opcode, timeout = nil, &)
    event = Event.new(:async, Fiber.current)

    prepare(pointerof(event), opcode, timeout) do |sqe|
      yield sqe
    end
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
