# The IO URING event loop.
#
# Only available on Linux targets and requires a recent kernel, at least Linux
# 5.19+, while we recommend Linux 6.13+ (see below).
#
# Executing an operation follows the regular async design: submit the operation
# to the local ring, suspend the fiber, wait for the operation to complete. When
# the CQE is received the fiber will be resumed.
#
# Running the loop usually checks the local CQEs, but once in a while and for
# blocking runs, it checks the CQEs for all the rings (hence the CQ lock, see
# below), so a scheduler blocked on a CPU bound fiber or a set of fibers that
# keeps re-enqueueing themselves, don't block runnable fibers from progressing,
# especially when there's a starving scheduler.
#
# ## Thread Safety
#
# While IO URING is thread safe in the kernel, the SQ and CQ rings aren't thread
# safe (by design) so each scheduler has its own ring. A main ring is created
# when the evloop is created (always used by the first scheduler), then a local
# ring is created and attached for additional schedulers. The local rings share
# the kernel resources of the main ring (WQ).
#
# On Linux kernels lower then 6.13 (determined at runtime) each SQ ring is
# protected by a lock because some operations still need to submit to the ring
# of another scheduler (e.g. to interrupt or to cancel pending R/W ops on
# IO::FileDescriptor before close). Linux 6.13+ kernels provide
# IORING_OP_MSG_RING and IORING_REGISTER_SYNC_CANCEL that make the lock
# pointless.
#
# CQ rings are always protected by a lock. See below for reasons.
#
# ## Rings
#
# The scheduler rings are kept in an array. The array never shrinks and only
# ever grows. Mutations are protected with a mutex and the array is duplicated,
# so we can safely iterate it without requiring the lock (copy on write).
#
# When a fiber scheduler is started, it is registered with the event loop
# (unique per execution context) that creates a ring for it and adds it to the
# rings array, trying to fill any nil entry.
#
# When a fiber scheduler is stopped, the execution context will drain its queue,
# which will block the current thread until the ring has been fully drained (all
# the SQE have completed), at which point it will be unregistered from the event
# loop that will nillify the entry in the rings array.
class Crystal::EventLoop::IoUring < Crystal::EventLoop
  # ^-- forward declaration for the require below to not create a module
end

require "c/poll"
require "c/sys/socket"
require "./io_uring/*"
require "./timers"

{% if flag?(:execution_context) %}
  # Each scheduler has its own ring, so we can avoid mutexes around the
  # submission queue for example (Linux 6.13+) and otherwise try to make sure
  # the lock is only slightly contented.
  #
  # OPTIMIZE: use a @[ThreadLocal] that would be set when a scheduler is
  # resumed on a thread, and unset when the scheduler detaches itself from
  # the thread.

  class Fiber
    module ExecutionContext
      module Scheduler
        # :nodoc:
        def __evloop_ring : Crystal::EventLoop::IoUring::Ring
          @__evloop_ring.not_nil!("Fiber::ExecutionContext::Scheduler#__evloop_ring cannot be nil")
        end

        # :nodoc:
        def __evloop_ring? : Crystal::EventLoop::IoUring::Ring?
          @__evloop_ring
        end

        # :nodoc:
        def __evloop_ring=(@__evloop_ring : Crystal::EventLoop::IoUring::Ring?)
        end
      end
    end
  end
{% end %}

{% if flag?(:preview_mt) %}
  # We must cancel pending R/W operations before we close the fd:
  #
  # 1. Closing a fd doesn't interrupt pending reads and writes in the linux
  # kernel, so fibers waiting to read or write would get stuck forever.
  #
  # 2. We must resume pending fibers to decrement the fdlock reference,
  # otherwise the fd would never get closed.
  #
  # Thanks to the read fdlock we can have at most one reader and one writer at
  # any time, so we only have a couple rings to remember, and put them on the IO
  # object directly.

  module Crystal::System::FileDescriptor
    @__evloop_reader = Atomic(Crystal::EventLoop::IoUring::Ring?).new(nil)
    @__evloop_writer = Atomic(Crystal::EventLoop::IoUring::Ring?).new(nil)

    # :nodoc:
    def __evloop_reader?
      @__evloop_reader.swap(nil, :relaxed)
    end

    # :nodoc:
    def __evloop_reader=(value)
      @__evloop_reader.set(value)
    end

    # :nodoc:
    def __evloop_writer?
      @__evloop_writer.swap(nil, :relaxed)
    end

    # :nodoc:
    def __evloop_writer=(value)
      @__evloop_writer.set(value)
    end
  end
{% end %}

class Crystal::EventLoop::IoUring < Crystal::EventLoop
  def self.default_file_blocking?
    false
  end

  def self.default_socket_blocking?
    false
  end

  # While io_uring was introduced in Linux 5.1, some features and opcodes that
  # we require are only available in Linux 5.19. The event loop is thus
  # incompatible with Linux 5.10 SLTS (EOL Jan 2031) and Linux 5.15 LTS (EOL
  # Dec 2026), but compatible with Linux 6.1 SLTS (EOL Aug 2033) and later.
  #
  # NOTE: when a feature or opcode isn't supported by the running kernel, we
  # could implement a fallback, reducing the kernel requirement down to 5.6:
  #
  # - IORING_FEAT_EXT_ARG: use a timerfd (one per ring)
  # - IORING_ASYNC_CANCEL_FD: save + cancel user_data instead of fd
  # - IORING_OP_MSG_RING: use an eventfd (one per ring)
  # - IORING_OP_OPENAT: use open(2)
  # - IORING_OP_SHUTDOWN: use shutdown(2)
  #
  # But without EBADR (Linux 5.19) we won't be notified of dropped CQEs which
  # is a critical error, assuming IORING_ASYNC_CANCEL_FD spares us a couple
  # pointers per IO object, and IORING_FEAT_EXT_ARG and IORING_OP_MSG_RING
  # spare use some complexity, the couple fds per ring however wouldn't have
  # any impact on newer kernels.
  def self.supported? : Bool
    return false unless System::IoUring.supported?

    System::IoUring.supports_feature?(LibC::IORING_FEAT_NODROP) &&          # 5.5 (EBADR: 5.19)
      System::IoUring.supports_feature?(LibC::IORING_FEAT_SUBMIT_STABLE) && # 5.5
      System::IoUring.supports_feature?(LibC::IORING_FEAT_RW_CUR_POS) &&    # 5.6
      System::IoUring.supports_feature?(LibC::IORING_FEAT_EXT_ARG) &&       # 5.11
      System::IoUring.supports_opcode?(LibC::IORING_OP_ACCEPT) &&           # 5.5
      System::IoUring.supports_opcode?(LibC::IORING_OP_ASYNC_CANCEL) &&     # 5.5 (IORING_ASYNC_CANCEL_FD: 5.19)
      System::IoUring.supports_opcode?(LibC::IORING_OP_CLOSE) &&            # 5.6
      System::IoUring.supports_opcode?(LibC::IORING_OP_CONNECT) &&          # 5.5
      System::IoUring.supports_opcode?(LibC::IORING_OP_LINK_TIMEOUT) &&     # 5.5
      System::IoUring.supports_opcode?(LibC::IORING_OP_MSG_RING) &&         # 5.18
      System::IoUring.supports_opcode?(LibC::IORING_OP_OPENAT) &&           # 5.15
      System::IoUring.supports_opcode?(LibC::IORING_OP_POLL_ADD) &&         # 5.1
      System::IoUring.supports_opcode?(LibC::IORING_OP_READ) &&             # 5.6
      System::IoUring.supports_opcode?(LibC::IORING_OP_RECVMSG) &&          # 5.3
      System::IoUring.supports_opcode?(LibC::IORING_OP_TIMEOUT) &&          # 5.4
      System::IoUring.supports_opcode?(LibC::IORING_OP_SEND) &&             # 5.6
      System::IoUring.supports_opcode?(LibC::IORING_OP_SHUTDOWN) &&         # 5.11
      System::IoUring.supports_opcode?(LibC::IORING_OP_SOCKET) &&           # 5.19 (unused, smoke test for EBADR/IORING_ASYNC_CANCEL_FD)
      System::IoUring.supports_opcode?(LibC::IORING_OP_WRITE)               # 5.6
  end

  DEFAULT_SQ_ENTRIES =  16
  DEFAULT_CQ_ENTRIES = 128

  # how long the poll thread should idle (in milliseconds)
  DEFAULT_SQ_THREAD_IDLE = {{(value = flag?("io_uring_sq_thread_idle")).is_a?(StringLiteral) && !value.empty? && value.to_i || nil}}

  # SQPOLL without fixed files was added in Linux 5.11 with CAP_SYS_NICE
  # privilege and Linux 5.13 unprivileged.
  protected def self.create_ring(ring = nil)
    Ring.new(
      sq_entries: DEFAULT_SQ_ENTRIES,
      cq_entries: DEFAULT_CQ_ENTRIES,
      sq_thread_idle: (DEFAULT_SQ_THREAD_IDLE if System::IoUring.supports_feature?(LibC::IORING_FEAT_SQPOLL_NONFIXED)),
      wq_fd: ring.try(&.fd)
    )
  end

  @main_ring : Ring
  @tick = Atomic(UInt32).new(0_u32)

  {% if flag?(:execution_context) %}
    # compiler can't type the ivar and fails to notice that it's always
    # initialized properly because of the compile time flag
    @rings = uninitialized Array(Ring?)
  {% end %}

  def initialize(parallelism : Int32)
    @main_ring = self.class.create_ring
    @timers = Timers(Event).new

    {% if flag?(:execution_context) %}
      @rings = Array(Ring?).new(parallelism) { nil }
      @rings[0] = @main_ring
    {% end %}

    # protects both @rings mutations (rare) and @timers (frequent)
    @mutex = Thread::Mutex.new
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      # @main_ring.close
      # @main_ring = self.class.create_ring
    end
  {% end %}

  private def ring : Ring
    {% if flag?(:execution_context) %}
      Fiber::ExecutionContext::Scheduler.current.__evloop_ring
    {% else %}
      @main_ring
    {% end %}
  end

  private def ring? : Ring?
    {% if flag?(:execution_context) %}
      Fiber::ExecutionContext::Scheduler.current?.try(&.__evloop_ring?)
    {% else %}
      @main_ring
    {% end %}
  end

  def run(blocking : Bool) : Bool
    enqueued = false

    system_run(blocking) do |fiber|
      fiber.enqueue
      enqueued = true
    end

    enqueued
  end

  {% if flag?(:execution_context) %}
    def run(queue : Fiber::List*, blocking : Bool) : Nil
      system_run(blocking) { |fiber| queue.value.push(fiber) }
    end

    # no lock: the evloop expects every scheduler to wait on its dedicated ring
    def lock?(&) : Bool
      yield
      true
    end

    def interrupt? : Bool
      interrupt_impl
    end

    # The @rings array might become full after some resizes (e.g. resize up, or
    # a resize down followed by a resize up while the rings haven't been closed,
    # yet), in which case we manually dup and grow the array so it's internal
    # buffer is never reallocated, so a full evloop run can safely iterate the
    # @rings array without locking the mutex.
    def register(scheduler : Fiber::ExecutionContext::Scheduler, index : Int32) : Nil
      if index == 0
        # the first scheduler always uses the main ring
        scheduler.__evloop_ring = @main_ring
        return
      end

      ring = self.class.create_ring(@main_ring)
      scheduler.__evloop_ring = ring

      @mutex.synchronize do
        if i = @rings.index(nil)
          @rings[i] = ring
        else
          # dup and grow the array
          rings = Array(Ring?).new(@rings.size * 2)
          @rings.each { |r| rings << r if r }
          rings << ring

          # the fence is required to make sure that the new array is fully
          # populated before we replace the @rings reference
          Atomic.fence(:sequentially_consistent)

          @rings = rings
        end
      end
    end

    def unregister(scheduler : Fiber::ExecutionContext::Scheduler) : Nil
      return unless ring = scheduler.__evloop_ring?
      scheduler.__evloop_ring = nil

      @mutex.synchronize do
        # thread safety: a nilable reference is a null pointer (non mixed
        # union): we can safely clear the value with a single store and don't
        # need to dup the @rings array
        if index = @rings.index(ring)
          @rings[index] = nil
        end
      end

      ring.close
    end
  {% end %}

  # Usually scans the local CQ ring only.
  #
  # When blocking (nothing to do) or every once in a while (to avoid some fibers
  # monopolizing the threads), it runs a full scan by iterating all the rings
  # one by one. This shall avoid ready events being blocked by a busy thread.
  #
  # Eventually processes timers.
  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    Crystal.trace :evloop, "run", blocking: blocking
    enqueued = 0

    {% if flag?(:execution_context) %}
      # dereference @rings once (it may be replaced in parallel)
      rings = @rings

      if rings.size > 1 && (blocking || once_in_a_while?)
        # iterate from a random entry to avoid a bias on the first ones
        start = Random.rand(0...rings.size)
        enqueued = process_all(rings, start) { |fiber| yield fiber }
      end
    {% end %}

    process_local(blocking) { |fiber| yield fiber } if enqueued == 0
    process_timers { |fiber| yield fiber }
  end

  private def once_in_a_while?
    @tick.add(1, :relaxed) == 51
  end

  MAX_PROCESS_ALL = 32

  private def process_all(rings, i, &)
    enqueued = 0

    rings.size.times do |j|
      next unless ring = rings[(i + j) % rings.size]?
      next if ring.waiting?

      # try to lock the CQ ring, abort if already locked (another thread is
      # already processing it)
      ring.cq_trylock? do
        process_cqes(ring) do |fiber|
          yield fiber

          # abort when an arbitrary amount of events ha been processed so we
          # don't block the current thread for longer than necessary
          return enqueued if (enqueued += 1) >= MAX_PROCESS_ALL
        end
      end
    end

    enqueued
  end

  private def process_local(blocking, &)
    ring = self.ring
    enqueued = 0

    # TODO: maybe only block on the CQ lock when *blocking* is true?
    ring.cq_lock do
      # check CQEs (avoiding syscalls)
      process_cqes(ring) do |fiber|
        yield fiber
        enqueued += 1
      end

      case enqueued
      when 0
        # CQ was empty: ask and/or wait for completions
        ring.waiting do
          min_complete, timeout = wait_until(blocking)
          ring.enter(min_complete: min_complete, flags: LibC::IORING_ENTER_GETEVENTS, timeout: timeout)
        end
      when ring.@cq_entries.value
        # CQ was full: tell kernel that it can report pending completions
        ring.enter(flags: LibC::IORING_ENTER_GETEVENTS)
      else
        return
      end

      process_cqes(ring) { |fiber| yield fiber }
    end
  end

  # Determines the relative timeout until the next ready timer.
  #
  # There is a race condition when a parallel scheduler adds a timer that would
  # resume earlier, but that scheduler will eventually wait on its own ring,
  # notice the new timeout, and resume on time.
  private def wait_until(blocking)
    min_complete, timeout = 0, nil

    if blocking
      min_complete = 1

      if abstime = @mutex.synchronize { @timers.next_ready? }
        timeout = abstime - System::Time.instant

        unless timeout.positive?
          # some timers have expired: don't wait
          min_complete = 0
          timeout = nil
        end
      end
    end

    {min_complete, timeout}
  end

  private def process_cqes(ring, &)
    ring.each_completed do |cqe|
      System::IoUring.trace(cqe)

      case event = Pointer(Event).new(cqe.value.user_data)
      when Pointer(Event).null
        # skip CQE without an Event
      else
        event.value.res = cqe.value.res
        # event.value.flags = cqe.value.flags
        yield event.value.fiber
      end
    end
  end

  private def process_timers(&)
    # can race, but the other thread that enqueued a timer shall notice
    return if @timers.empty?

    # dequeue ready timers (upto arbitrary limit)
    timers = uninitialized Pointer(Event)[32]
    count = 0

    @mutex.synchronize do
      @timers.dequeue_ready do |event|
        timers[count] = event
        count += 1
        break if count == timers.size
      end
    end

    # we can process the timers after releasing the timers' lock
    timers.to_slice[0, count].each do |event|
      fiber = event.value.fiber

      if event.value.type.select_timeout?
        next unless select_action = fiber.timeout_select_action
        fiber.timeout_select_action = nil
        next unless select_action.time_expired?
        fiber.@timeout_event.as(FiberEvent).clear
      end

      yield fiber
    end
  end

  def interrupt : Nil
    interrupt_impl
  end

  private def interrupt_impl : Bool
    # search a waiting ring to wakeup
    waiting_ring =
      {% if flag?(:execution_context) %}
        @rings.find(&.try(&.waiting?))
      {% else %}
        @main_ring
      {% end %}
    return false unless waiting_ring

    # try to notify the waiting ring through the local ring (every scheduler
    # should have one) but there might be bare threads, so we fallback to a
    # syscall (Linux 6.13) or to a cross ring submit for older kernels
    ring = ring?
    ring = waiting_ring if ring.nil? && !System::IoUring.supports_register_send_msg_ring?

    if ring
      ring.submit do |sqe|
        sqe.value.opcode = LibC::IORING_OP_MSG_RING
        sqe.value.fd = waiting_ring.fd
      end
    else
      sqe = LibC::IoUringSqe.new
      sqe.opcode = LibC::IORING_OP_MSG_RING
      sqe.fd = waiting_ring.fd
      res = System::Syscall.io_uring_register(-1, LibC::IORING_REGISTER_SEND_MSG_RING, pointerof(sqe).as(Void*), 1)
      raise RuntimeError.from_os_error("io_uring_register(IORING_REGISTER_SEND_MSG_RING)", Errno.new(-res)) if res < 0
    end

    true
  end

  # Blocks the current thread until the local SQ ring has been drained.
  # Doesn't process @timers (another scheduler shall process them).
  def drain(& : Fiber ->) : Nil
    return unless ring = ring?

    ring.cq_lock do
      drain_event = uninitialized Event

      # Submit a NOP to drain the local ring: it will only generate a CQE
      # after every operations submitted before it have completed.
      ring.submit do |sqe|
        sqe.value.opcode = LibC::IORING_OP_NOP
        sqe.value.flags = LibC::IOSQE_IO_DRAIN
        sqe.value.user_data = pointerof(drain_event).address.to_u64!
      end

      # Wait & process CQEs until we get the CQE for the above NOP.
      loop do
        ring.each_completed do |cqe|
          System::IoUring.trace(cqe)

          case event = Pointer(Event).new(cqe.value.user_data)
          when Pointer(Event).null
            # skip CQE without an Event
          when pointerof(drain_event)
            # done: the SQ ring has been drained
            return
          else
            event.value.res = cqe.value.res
            # event.value.flags = cqe.value.flags
            yield event.value.fiber
          end
        end

        ring.enter(min_complete: 1, flags: LibC::IORING_ENTER_GETEVENTS)
      end
    end
  end

  # (cancelable) timers

  def add_timer(event : Event*) : Nil
    @mutex.synchronize { @timers.add(event) }
  end

  def delete_timer(event : Event*) : Nil
    @mutex.synchronize { @timers.delete(event) }
  end

  # fiber interface, see Crystal::EventLoop

  def sleep(duration : Time::Span) : Nil
    async_impl(:sleep) do |event|
      event.value.timeout = duration

      ring.submit do |sqe|
        sqe.value.opcode = LibC::IORING_OP_TIMEOUT
        sqe.value.user_data = event.address.to_u64!
        sqe.value.addr = event.value.timespec.address.to_u64!
        sqe.value.len = 1
      end
    end
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(:select_timeout, fiber)
  end

  # file descriptor interface, see Crystal::EventLoop::FileDescriptor

  def pipe(read_blocking : Bool?, write_blocking : Bool?) : {IO::FileDescriptor, IO::FileDescriptor}
    r, w = System::FileDescriptor.system_pipe
    System::FileDescriptor.set_blocking(r, false) if read_blocking == false
    System::FileDescriptor.set_blocking(w, false) if write_blocking == false
    {
      IO::FileDescriptor.new(handle: r),
      IO::FileDescriptor.new(handle: w),
    }
  end

  def open(path : String, flags : Int32, permissions : File::Permissions, blocking : Bool?) : {System::FileDescriptor::Handle, Bool} | Errno
    path.check_no_null_byte

    fd = async(LibC::IORING_OP_OPENAT) do |sqe|
      sqe.value.fd = LibC::AT_FDCWD
      sqe.value.addr = path.to_unsafe.address.to_u64!
      sqe.value.__u2.open_flags = flags | LibC::O_CLOEXEC
      sqe.value.len = permissions
    end
    return Errno.new(-fd) if fd < 0

    blocking = true if blocking.nil?
    System::FileDescriptor.set_blocking(fd, false) if blocking
    {fd, blocking}
  end

  def read(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    before_suspend =
      {% if flag?(:preview_mt) %}
        file_descriptor.__evloop_reader = ring
        -> {
          if file_descriptor.closed? && file_descriptor.__evloop_reader?
            cancel(file_descriptor.fd)
          end
        }
      {% else %}
        nil
      {% end %}

    async_rw(LibC::IORING_OP_READ, file_descriptor, slice, file_descriptor.@read_timeout, before_suspend) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Read timed out")
      when Errno::EBADF
        raise IO::Error.new("File not open for reading", target: file_descriptor)
      else
        raise IO::Error.from_os_error("read", errno, target: file_descriptor)
      end
    end
  ensure
    {% if flag?(:preview_mt) %}
      file_descriptor.__evloop_reader = nil
    {% end %}
  end

  def wait_readable(file_descriptor : System::FileDescriptor) : Nil
    async_poll(file_descriptor, LibC::POLLIN | LibC::POLLRDHUP, file_descriptor.@read_timeout) { "Read timed out" }
  end

  def write(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    before_suspend =
      {% if flag?(:preview_mt) %}
        file_descriptor.__evloop_writer = ring
        -> {
          if file_descriptor.closed? && file_descriptor.__evloop_writer?
            cancel(file_descriptor.fd)
          end
        }
      {% else %}
        nil
      {% end %}

    async_rw(LibC::IORING_OP_WRITE, file_descriptor, slice, file_descriptor.@write_timeout, before_suspend) do |errno|
      case errno
      when Errno::ECANCELED
        raise IO::TimeoutError.new("Write timed out")
      when Errno::EBADF
        raise IO::Error.new("File not open for writing", target: file_descriptor)
      else
        raise IO::Error.from_os_error("write", errno, target: file_descriptor)
      end
    end
  ensure
    {% if flag?(:preview_mt) %}
      file_descriptor.__evloop_writer = nil
    {% end %}
  end

  def wait_writable(file_descriptor : System::FileDescriptor) : Nil
    async_poll(file_descriptor, LibC::POLLOUT, file_descriptor.@write_timeout) { "Write timed out" }
  end

  def reopened(file_descriptor : System::FileDescriptor) : Nil
    # nothing to do
  end

  def shutdown(file_descriptor : System::FileDescriptor) : Nil
    {% if flag?(:preview_mt) %}
      if reader_ring = file_descriptor.__evloop_reader?
        cancel(file_descriptor.fd, ring: reader_ring)
      end
      if (writer_ring = file_descriptor.__evloop_writer?) && (writer_ring != reader_ring)
        cancel(file_descriptor.fd, ring: writer_ring)
      end
    {% else %}
      ring.submit do |sqe|
        sqe.value.opcode = LibC::IORING_OP_ASYNC_CANCEL
        sqe.value.fd = file_descriptor.fd
        sqe.value.__u2.cancel_flags = LibC::IORING_ASYNC_CANCEL_FD | LibC::IORING_ASYNC_CANCEL_ALL
      end
    {% end %}
  end

  def close(file_descriptor : System::FileDescriptor) : Nil
    if fd = file_descriptor.close_volatile_fd?
      async_close(fd)
    end
  end

  # socket interface, see Crystal::EventLoop::Socket

  def socket(family : ::Socket::Family, type : ::Socket::Type, protocol : ::Socket::Protocol, blocking : Bool?) : {::Socket::Handle, Bool}
    blocking = true if blocking.nil?
    socket = System::Socket.socket(family, type, protocol, blocking)
    {socket, blocking}
  end

  def socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : Tuple({::Socket::Handle, ::Socket::Handle}, Bool)
    socket = System::Socket.socketpair(type, protocol, blocking: true)
    {socket, true}
  end

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

  def accept(socket : ::Socket) : {::Socket::Handle, Bool}?
    res = async(LibC::IORING_OP_ACCEPT, socket.@read_timeout) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.__u2.accept_flags = LibC::SOCK_CLOEXEC
    end
    return {res, true} unless res < 0

    errno = Errno.new(-res)
    if errno == Errno::ECANCELED
      raise IO::TimeoutError.new("Accept timed out")
    elsif !socket.closed?
      raise ::Socket::Error.from_os_error("accept", errno)
    end
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : Time::Span?) : IO::Error?
    sockaddr = address.to_unsafe # OPTIMIZE: #to_unsafe allocates (not needed)
    addrlen = address.size

    res = async(LibC::IORING_OP_CONNECT, timeout) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.addr = sockaddr.address.to_u64!
      sqe.value.__u1.off = addrlen.to_u64!
    end
    return if res == 0

    errno = Errno.new(-res)
    if errno == Errno::ECANCELED
      IO::TimeoutError.new("Connect timed out")
    elsif errno != Errno::EISCONN
      ::Socket::ConnectError.from_os_error("connect", errno)
    end
  end

  # TODO: support socket.@write_timeout (?)
  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    sockaddr = address.to_unsafe # OPTIMIZE: #to_unsafe allocates (not needed)
    addrlen = address.size

    res = async(LibC::IORING_OP_SEND) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.addr = slice.to_unsafe.address.to_u64!
      sqe.value.len = slice.size.to_u64!
      sqe.value.__u1.addr2 = sockaddr.address.to_u64!
      sqe.value.addr_len[0] = addrlen.to_u16!
    end

    if res == 0
      check_open(socket)
    elsif res < 0
      raise ::Socket::Error.from_os_error("Error sending datagram to #{address}", Errno.new(-res))
    end

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

    if res == 0
      check_open(socket)
    elsif res < 0
      raise IO::Error.from_os_error("recvfrom", Errno.new(-res), target: socket)
    end

    {res, ::Socket::Address.from(pointerof(sockaddr).as(LibC::Sockaddr*), msghdr.msg_namelen)}
  end

  def shutdown(socket : ::Socket) : Nil
    # unlike IO::FileDescriptor, we can merely shut down the socket to interrupt
    # pending operations (read, write, accept, ...)
    #
    # OPTIMIZE: we could skip calling shutdown when there's no waiter (could be
    # a mere add/sub relaxed atomic).

    # we must wait for the shutdown to complete, otherwise we might immediately
    # submit a close... that could be executed before the shutdown (oops).
    async(LibC::IORING_OP_SHUTDOWN) do |sqe|
      sqe.value.fd = socket.fd
      sqe.value.len = LibC::SHUT_RDWR
    end
  end

  def close(socket : ::Socket) : Nil
    # sync with `Socket#socket_close`
    if fd = socket.close_volatile_fd?
      async_close(fd)
    end
  end

  # internals

  private def check_open(io)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  private def cancel(fd, ring = self.ring)
    if (ring == self.ring) || !System::IoUring.supports_register_sync_cancel?
      # submit to local ring, or to another ring for legacy kernels
      ring.submit do |sqe|
        sqe.value.opcode = LibC::IORING_OP_ASYNC_CANCEL
        sqe.value.fd = fd
        sqe.value.__u2.cancel_flags = LibC::IORING_ASYNC_CANCEL_FD | LibC::IORING_ASYNC_CANCEL_ALL
      end
    else
      # use sync cancel for modern kernels to notify another ring, but don't wait
      # for the cancelation to have completed (zero timeout) so it behaves as an
      # async cancel (see https://github.com/axboe/liburing/discussions/608)
      reg = LibC::IoUringSyncCancelReg.new
      reg.fd = fd
      reg.flags = LibC::IORING_ASYNC_CANCEL_FD | LibC::IORING_ASYNC_CANCEL_ALL
      reg.timeout.tv_sec = 0
      reg.timeout.tv_nsec = 0

      if errno = ring.register?(LibC::IORING_REGISTER_SYNC_CANCEL, pointerof(reg), 1)
        return if errno.in?(Errno::ENOENT, Errno::EALREADY, Errno::ETIME)
        raise RuntimeError.from_os_error("io_uring_register(IORING_REGISTER_SYNC_CANCEL)", errno)
      end
    end
  end

  private def async_rw(opcode, io, slice, timeout, before_suspend = nil, &)
    loop do
      res = async(opcode, timeout, before_suspend) do |sqe|
        sqe.value.fd = io.fd
        sqe.value.__u1.off = -1
        sqe.value.addr = slice.to_unsafe.address.to_u64!
        sqe.value.len = slice.size
      end
      return res if res >= 0

      check_open(io)

      errno = Errno.new(-res)
      yield errno unless errno == Errno::EINTR
    end
  end

  private def async_poll(io, poll_events, timeout, &)
    res = async(LibC::IORING_OP_POLL_ADD, timeout) do |sqe|
      sqe.value.fd = io.fd
      sqe.value.__u2.poll_events = poll_events | LibC::POLLERR | LibC::POLLHUP
    end
    check_open(io)
    raise IO::TimeoutError.new(yield) if res == -LibC::ECANCELED
  end

  private def async_close(fd)
    res = async(LibC::IORING_OP_CLOSE) do |sqe|
      sqe.value.fd = fd
    end
    return if res == 0

    errno = Errno.new(-res)
    return if errno.in?(Errno::EINTR, Errno::EINPROGRESS)

    raise IO::Error.from_os_error("Error closing file", errno)
  end

  private def async(opcode, link_timeout = nil, before_suspend = nil, &)
    sqes = uninitialized Pointer(LibC::IoUringSqe)[2]

    async_impl do |event|
      count = link_timeout ? 2 : 1

      ring.submit(sqes.to_slice[0, count]) do
        sqes[0].value.opcode = opcode
        sqes[0].value.user_data = event.address.to_u64!
        yield sqes[0]

        if link_timeout
          event.value.timeout = link_timeout

          # chain the operations
          sqes[0].value.flags = sqes[0].value.flags | LibC::IOSQE_IO_LINK

          # configure the timeout operation
          sqes[1].value.opcode = LibC::IORING_OP_LINK_TIMEOUT
          sqes[1].value.addr = event.value.timespec.address.to_u64!
          sqes[1].value.len = 1
        end
      end

      before_suspend.try(&.call)
    end
  end

  private def async_impl(type : Event::Type = :async, &)
    event = Event.new(type, Fiber.current)
    yield pointerof(event)
    Fiber.suspend
    event.res
  end
end
