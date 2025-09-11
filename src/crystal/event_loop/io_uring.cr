# forward declaration for the require below to not create a module
class Crystal::EventLoop::IoUring < Crystal::EventLoop
end

require "c/poll"
require "c/sys/socket"
require "../system/unix/io_uring"
require "./io_uring/*"

# WARNING: IOSQE_CQE_SKIP_SUCCESS is incompatible with IOSQE_IO_DRAIN!

class Crystal::EventLoop::IoUring < Crystal::EventLoop
  @@supports_sendto = true

  def self.supported? : Bool
    return false unless System::IoUring.supported?

    @@supports_openat = System::IoUring.supports_opcode?(LibC::IORING_OP_OPENAT)
    @@supports_sendto = System::IoUring.supports_opcode?(LibC::IORING_OP_SEND)

    System::IoUring.supports_feature?(LibC::IORING_FEAT_NODROP) &&
      System::IoUring.supports_feature?(LibC::IORING_FEAT_RW_CUR_POS) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_READ) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_WRITE) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_CONNECT) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_ACCEPT) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_SENDMSG) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_RECVMSG) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_CLOSE) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_LINK_TIMEOUT) &&
      System::IoUring.supports_opcode?(LibC::IORING_OP_ASYNC_CANCEL)
  end

  def initialize
    @ring = System::IoUring.new(
      sq_entries: 16,
      cq_entries: 128,
      sq_idle: (2000 if System::IoUring.supports_feature?(LibC::IORING_FEAT_SQPOLL_NONFIXED))
    )
  end

  def after_fork_before_exec : Nil
    @ring.close
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      @ring.close

      @ring = System::IoUring.new(
        sq_entries: 16,
        cq_entries: 128,
        sq_idle: (2000 if System::IoUring.supports_feature?(LibC::IORING_FEAT_SQPOLL_NONFIXED))
      )
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
      @ring.enter(min_complete: blocking ? 1_u32 : 0_u32, flags: LibC::IORING_ENTER_GETEVENTS)
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
      trace(cqe)

      # skip CQE not associated with an event
      next unless event = Pointer(Event).new(cqe.value.user_data)

      fiber = event.value.fiber

      if event.value.type.select_timeout?
        next unless select_action = fiber.timeout_select_action
        fiber.timeout_select_action = nil
        next unless select_action.time_expired?
        fiber.@timeout_event.as(FiberEvent).clear
      end

      event.value.res = cqe.value.res
      # event.value.flags = cqe.value.flags

      yield fiber
    end
  end

  def interrupt : Nil
    # the atomic makes sure we only write once (no need to write multiple times)
    @eventfd.write(1) if @interrupted.test_and_set
  end

  # timers

  # FIXME: with threads/multiple rings, we'll need to know which ring the
  # timeout has been submitted to to be able to cancel it; using our own queue
  # of timers with a single timerfd might be simpler.

  def add_timer(event : Event*) : Nil
    sqe, ts = @ring.next_sqe_with_timespec

    timeout = event.value.timeout
    ts.value.tv_sec = typeof(ts.value.tv_sec).new!(timeout.@seconds)
    ts.value.tv_nsec = typeof(ts.value.tv_nsec).new!(timeout.@nanoseconds)

    sqe.value.opcode = LibC::IORING_OP_TIMEOUT
    sqe.value.user_data = event.address.to_u64!
    sqe.value.addr = ts.address.to_u64!
    sqe.value.len = 1
    trace(sqe)

    @ring.submit
  end

  def delete_timer(event : Event*) : Nil
    sqe = @ring.next_sqe
    sqe.value.opcode = LibC::IORING_OP_TIMEOUT_REMOVE
    sqe.value.flags = LibC::IOSQE_CQE_SKIP_SUCCESS
    sqe.value.addr = event.address.to_u64!
    trace(sqe)

    @ring.submit
  end

  # fiber interface, see Crystal::EventLoop

  def sleep(duration : Time::Span) : Nil
    res = async_timeout(:sleep, duration)
    # assert(res == -ETIME)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(:select_timeout, fiber)
  end

  # file descriptor interface, see Crystal::EventLoop::FileDescriptor

  def open(path : String, flags : Int32, permissions : File::Permissions, blocking : Bool?) : {System::FileDescriptor::Handle, Bool} | Errno
    flags |= LibC::O_CLOEXEC
    blocking = true if blocking.nil?

    if @@supports_openat
      fd = async(LibC::IORING_OP_OPENAT, opcode) do |sqe|
        sqe.value.fd = LibC::AT_FDCWD
        sqe.value.addr = path.to_unsafe.address.to_u64!
        sqe.value.open_flags = flags
        sqe.value.len = permissions
      end
      return Errno.new(-fd) if fd < 0
    else
      fd = LibC.open(path, flags, permissions)
      return Errno.value if fd == -1
    end

    System::FileDescriptor.set_blocking(fd, false) if blocking
    {fd, blocking}
  end

  def read(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_READ, file_descriptor, slice, file_descriptor.@read_timeout) do |errno|
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
    async_poll(file_descriptor, LibC::POLLIN | LibC::POLLRDHUP, file_descriptor.@read_timeout) { "Read timed out" }
  end

  def write(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, file_descriptor, slice, file_descriptor.@write_timeout) do |errno|
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
    async_poll(file_descriptor, LibC::POLLOUT, file_descriptor.@write_timeout) { "Write timed out" }
  end

  def reopened(file_descriptor : System::FileDescriptor) : Nil
    # TODO: do we need to cancel pending operations?
  end

  def close(file_descriptor : System::FileDescriptor) : Nil
    # sync with `FileDescriptor#file_descriptor_close`: prevent actual close
    fd = file_descriptor.@volatile_fd.swap(-1, :relaxed)
    return if fd == -1

    async_close(fd) do |sqe|
      # one thread closing a fd won't interrupt reads or writes happening in
      # other threads, for example a blocked read on a fifo will keep blocking,
      # while close would have finished and closed the fd; we thus explicitly
      # cancel any pending operations on the fd before we try to close
      #
      # FIXME: with threads and multiple rings, we'll need to know which rings
      # have pending operations for the fd (which op/event for each ring) and
      # tell the rings to cancel said ops (can't just say to cancel all ops for
      # fd so we can close in parallel)
      sqe.value.opcode = LibC::IORING_OP_ASYNC_CANCEL
      sqe.value.sflags.cancel_flags = LibC::IORING_ASYNC_CANCEL_FD
      sqe.value.fd = fd
    end
  end

  # socket interface, see Crystal::EventLoop::Socket

  def read(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_READ, socket, slice, socket.@read_timeout) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Read timed out")
      else
        raise IO::Error.from_os_error("read", errno, target: socket)
      end
    end
  end

  def wait_readable(socket : ::Socket) : Nil
    async_poll(socket, LibC::POLLIN | LibC::POLLRDHUP, socket.@read_timeout) { "Read timed out" }
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    async_rw(LibC::IORING_OP_WRITE, socket, slice, socket.@write_timeout) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Write timed out")
      else
        raise IO::Error.from_os_error("write", errno, target: socket)
      end
    end
  end

  def wait_writable(socket : ::Socket) : Nil
    async_poll(socket, LibC::POLLOUT, socket.@write_timeout) { "Write timed out" }
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
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

  # TODO: support socket.@write_timeout (?)
  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    sockaddr = address.to_unsafe # OPTIMIZE: #to_unsafe allocates (not needed)
    addrlen = address.size

    if @@supports_sendto
      res = async(LibC::IORING_OP_SEND) do |sqe|
        sqe.value.fd = socket.fd
        sqe.value.addr = slice.to_unsafe.address.to_u64!
        sqe.value.len = slice.size.to_u64!
        sqe.value.u1.addr2 = sockaddr.address.to_u64!
        sqe.value.addr_len[0] = addrlen.to_u16!
      end
      return res unless res < 0

      unless res == -LibC::EINVAL
        raise ::Socket::Error.from_os_error("Error sending datagram to #{address}", Errno.new(-res))
      end
      @@supports_sendto = false
    end

    # fallback to SENDMSG
    iovec = LibC::Iovec.new(iov_base: slice.to_unsafe, iov_len: slice.size)
    msghdr = LibC::Msghdr.new(msg_name: sockaddr, msg_namelen: addrlen, msg_iov: pointerof(iovec), msg_iovlen: 1)

    res = async(LibC::IORING_OP_SENDMSG) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.addr = pointerof(msghdr).address.to_u64!
    end

    raise ::Socket::Error.from_os_error("Error sending datagram to #{address}", Errno.new(-res)) if res < 0
    res
  end

  # TODO: support socket.@read_timeout (?)
  def receive_from(socket : ::Socket, slice : Bytes) : {Int32, ::Socket::Address}
    sockaddr = LibC::SockaddrStorage.new
    sockaddr.ss_family = socket.family
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    # as of linux 6.12 there is no IORING_OP_RECVFROM
    iovec = LibC::Iovec.new(iov_base: slice.to_unsafe, iov_len: slice.size)
    msghdr = LibC::Msghdr.new(msg_name: pointerof(sockaddr), msg_namelen: addrlen, msg_iov: pointerof(iovec), msg_iovlen: 1)

    res = async(LibC::IORING_OP_RECVMSG) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.addr = pointerof(msghdr).address.to_u64!
    end

    raise IO::Error.from_os_error("recvfrom", Errno.new(-res), target: socket) if res < 0
    {res, ::Socket::Address.from(pointerof(sockaddr).as(LibC::Sockaddr*), msghdr.msg_namelen)}
  end

  def close(socket : ::Socket) : Nil
    # sync with `Socket#socket_close`
    fd = socket.@volatile_fd.swap(-1, :relaxed)
    return if fd == -1

    async_close(fd) do |sqe|
      # we must shutdown a socket before closing it, otherwise a pending accept
      # or read won't be interrupted for example;
      sqe.value.opcode = LibC::IORING_OP_SHUTDOWN
      sqe.value.fd = fd
      sqe.value.len = LibC::SHUT_RD # FIXME: add SHUT_WR too (?)
    end
  end

  # internals

  private def check_open(io)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  private def async_rw(opcode, io, slice, timeout, &)
    loop do
      res = async(opcode, timeout) do |sqe|
        sqe.value.fd = io.fd
        sqe.value.u1.off = -1
        sqe.value.addr = slice.to_unsafe.address.to_u64!
        sqe.value.len = slice.size
      end
      return res if res >= 0

      check_open(io)
      yield Errno.new(-res) unless res == -LibC::EINTR
    end
  end

  private def async_poll(io, poll_events, timeout, &)
    res = async(LibC::IORING_OP_POLL_ADD, timeout) do |sqe|
      sqe.value.fd = io.fd
      sqe.value.sflags.poll_events = poll_events | LibC::POLLERR | LibC::POLLHUP
    end
    check_open(io)
    raise IO::TimeoutError.new(yield) if res == -LibC::ECANCELED
  end

  private def async_close(fd, &)
    res = async_impl do |event|
      @ring.reserve(2)

      # linux won't interrupt pending operations on a file descriptor when it
      # closes it, we thus first create an operation to cancel any pending
      # operations; we don't attach that cancel operation to an event: handling
      # the CQE for close is enough
      cancel_sqe = @ring.unsafe_next_sqe
      cancel_sqe.value.flags = LibC::IOSQE_IO_LINK | LibC::IOSQE_IO_HARDLINK | LibC::IOSQE_CQE_SKIP_SUCCESS
      yield cancel_sqe
      trace(cancel_sqe)

      # then we setup the close operation
      close_sqe = @ring.unsafe_next_sqe
      close_sqe.value.opcode = LibC::IORING_OP_CLOSE
      close_sqe.value.user_data = event.address.to_u64!
      close_sqe.value.fd = fd
      trace(close_sqe)
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

  private def async_timeout(type : Event::Type, duration)
    async_impl(type) do |event|
      @ring.reserve(1)

      sqe, ts = @ring.unsafe_next_sqe_with_timespec

      ts.value.tv_sec = typeof(ts.value.tv_sec).new(duration.@seconds)
      ts.value.tv_nsec = typeof(ts.value.tv_nsec).new(duration.@nanoseconds)

      sqe.value.opcode = LibC::IORING_OP_TIMEOUT
      sqe.value.user_data = event.address.to_u64!
      sqe.value.addr = ts.address.to_u64!
      sqe.value.len = 1
      trace(sqe)
    end
  end

  private def async(opcode, timeout = nil, &)
    async_impl do |event|
      @ring.reserve(timeout ? 2 : 1)

      # configure the operation
      op_sqe = @ring.unsafe_next_sqe
      op_sqe.value.opcode = opcode
      op_sqe.value.user_data = event.address.to_u64!
      yield op_sqe

      if timeout
        # chain the above operation with the next one
        op_sqe.value.flags = op_sqe.value.flags | LibC::IOSQE_IO_LINK
        trace(op_sqe)

        # configure the link timeout operation (applies to the above operation)
        link_sqe, ts = @ring.unsafe_next_sqe_with_timespec

        ts.value.tv_sec = typeof(ts.value.tv_sec).new(timeout.@seconds)
        ts.value.tv_nsec = typeof(ts.value.tv_nsec).new(timeout.@nanoseconds)

        link_sqe.value.opcode = LibC::IORING_OP_LINK_TIMEOUT
        link_sqe.value.flags = LibC::IOSQE_CQE_SKIP_SUCCESS
        link_sqe.value.addr = ts.address.to_u64!
        link_sqe.value.len = 1
        trace(link_sqe)
      else
        trace(op_sqe)
      end
    end
  end

  private def async_impl(type = Event::Type::Async, &)
    event = Event.new(type, Fiber.current)
    yield pointerof(event)
    @ring.submit
    Fiber.suspend
    event.res
  end

  private def trace(cqe : LibC::IoUringCqe*)
    Crystal.trace :evloop, "cqe",
      user_data: Pointer(Void).new(cqe.value.user_data),
      res: cqe.value.res >= 0 ? cqe.value.res : Errno.new(-cqe.value.res).to_s,
      flags: cqe.value.flags
  end

  private def trace(sqe : LibC::IoUringSqe*)
    Crystal.trace :evloop, "sqe",
      user_data: Pointer(Void).new(sqe.value.user_data),
      opcode: System::IoUring::OPCODES.new(sqe.value.opcode).to_s,
      flags: System::IoUring::IOSQES.new(sqe.value.flags).to_s,
      fd: sqe.value.fd,
      addr: Pointer(Void).new(sqe.value.addr),
      len: sqe.value.len
    # LibC.dprintf(2, sqe.value.pretty_inspect)
  end
end
