{% skip_file unless flag?(:linux) %}

require "./syscall/*"
require "time/span"

# An interface to interact with Linux's io_uring subsystem. One IoUring instance
# represents a pair of lock-free ring-based queues in memory shared between the
# application and the running Kernel. There is the submission queue where the
# application can write requests and the completion queue where the kernel
# will write one response for each request. The operation must be synchronized
# carefully as the Kernel is using its own thread to interact with these queues
# without blocking the application.
#
# This class is NOT thread-safe.
class Crystal::System::IoUring
  # Obtains runtime information about what io_uring features and operations are available.
  struct Probe
    property has_io_uring = false
    property features = Syscall::IoUringFeatures::None
    property operations = Syscall::IoUringOpAsFlag::None

    # This method should never raise exceptions
    def initialize
      params = Syscall::IoUringParams.new
      fd = Syscall.io_uring_setup(1, pointerof(params))
      return if fd < 0

      probe = Syscall::IoUringProbe(255).new
      ret = Syscall.io_uring_register(fd, Syscall::IoUringRegisterOp::REGISTER_PROBE, pointerof(probe).as(Void*), 255)
      Syscall.close(fd)
      return if fd < 0

      @has_io_uring = true
      @features = params.features

      {probe.ops_len, 64}.min.times do |i|
        operation = probe.ops[i]
        next unless operation.flags.supported?
        flag = Syscall::IoUringOpAsFlag.from_value?(1u64 << operation.op)
        next unless flag
        @operations |= flag
      end
    end
  end

  @@probe : Probe?
  @@available : Bool?

  def self.probe
    @@probe ||= Probe.new
  end

  # Returns `true` if there are enough features for Crystal's stdlib.
  def self.available?
    available = @@available
    return available unless available.nil?

    probe = self.probe

    # This should return `true` on Linux 5.6+ unless it was built with io_uring disabled
    @@available = probe.has_io_uring &&
                  probe.features.nodrop? && # NODROP is required because we do not keep track of inflight requests
                  probe.operations.nop? &&
                  (probe.operations.read? || probe.operations.readv?) &&
                  (probe.operations.write? || probe.operations.writev?) &&
                  probe.operations.timeout? &&
                  probe.operations.accept? &&
                  probe.operations.connect?
  end

  # Creates a new io_uring instance with room for at least `sq_entries_hint`. This value is just
  # a hint. It will be rounded up to the nearest power of two and it will max at 32768.
  def initialize(sq_entries_hint : UInt32 = 128)
    @params = Syscall::IoUringParams.new

    # Just clamp to the maximum value if `sq_entries_hint` is too high.
    @params.flags |= Syscall::IoUringFlags::CLAMP

    # TODO: Consider using SQPOLL when running as root.

    {% if flag? :preview_mt %}
      # TODO: Use ATTACH_WQ to share kernel resources between threads.
    {% end %}

    @fd = Syscall.io_uring_setup(sq_entries_hint, pointerof(@params))

    if @fd < 0
      raise RuntimeError.from_os_error("Failed to create io_uring interface", Errno.new(-@fd))
    end

    @submission_queue_mmap = Pointer(Void).null
    @completion_queue_mmap = Pointer(Void).null
    @submission_entries = Pointer(Syscall::IoUringSqe).null

    # Since Linux 5.4 both queues can be mapped in a single call to `mmap`.
    if @params.features.single_mmap?
      mem = Syscall.mmap(Pointer(Void).null, {sq_size, cq_size}.max,
        Syscall::Prot::READ | Syscall::Prot::WRITE, Syscall::Map::SHARED | Syscall::Map::POPULATE,
        @fd, Syscall::IORING_OFF_SQ_RING)

      if mem.address.to_i64! < 0
        err = Errno.new(-mem.address.to_i64!.to_i)
        raise RuntimeError.from_os_error("Cannot allocate submission and completion queues", err)
      end

      @completion_queue_mmap = @submission_queue_mmap = mem
    else
      mem = Syscall.mmap(Pointer(Void).null, sq_size,
        Syscall::Prot::READ | Syscall::Prot::WRITE, Syscall::Map::SHARED | Syscall::Map::POPULATE,
        @fd, Syscall::IORING_OFF_SQ_RING)

      if mem.address.to_i64! < 0
        err = Errno.new(-mem.address.to_i64!.to_i)
        raise RuntimeError.from_os_error("Cannot allocate submission queue", err)
      end

      @submission_queue_mmap = mem

      mem = Syscall.mmap(Pointer(Void).null, cq_size,
        Syscall::Prot::READ | Syscall::Prot::WRITE, Syscall::Map::SHARED | Syscall::Map::POPULATE,
        @fd, Syscall::IORING_OFF_CQ_RING)

      if mem.address.to_i64! < 0
        err = Errno.new(-mem.address.to_i64!.to_i)
        raise RuntimeError.from_os_error("Cannot allocate completion queue", err)
      end

      @completion_queue_mmap = mem
    end

    mem = Syscall.mmap(Pointer(Void).null, sq_entries_size,
      Syscall::Prot::READ | Syscall::Prot::WRITE, Syscall::Map::SHARED | Syscall::Map::POPULATE,
      @fd, Syscall::IORING_OFF_SQES)

    if mem.address.to_i64! < 0
      err = Errno.new(-mem.address.to_i64!.to_i)
      raise RuntimeError.from_os_error("Cannot allocate submission entries", err)
    end

    @submission_entries = mem.as(Syscall::IoUringSqe*)

    @submission_queue = SubmissionQueue.new(@fd, @submission_queue_mmap, @params.sq_off)
    @completion_queue = CompletionQueue.new(@fd, @completion_queue_mmap, @params.cq_off)
    @closed = false
  end

  def finalize
    close unless @closed
  end

  def close
    return if @closed
    @closed = true

    if @submission_queue_mmap && @submission_queue_mmap == @completion_queue_mmap
      Syscall.munmap(@submission_queue_mmap, {sq_size, cq_size}.max)
    end

    if @submission_queue_mmap
      Syscall.munmap(@submission_queue_mmap, sq_size)
    end

    if @completion_queue_mmap
      Syscall.munmap(@completion_queue_mmap, cq_size)
    end

    if @completion_queue_mmap
      Syscall.munmap(@completion_queue_mmap, sq_entries_size)
    end

    if @fd > 0
      Syscall.close(@fd)
    end
  end

  private def sq_size
    LibC::SizeT.new(@params.sq_off.array + @params.sq_entries * sizeof(UInt32))
  end

  private def cq_size
    LibC::SizeT.new(@params.cq_off.cqes + @params.cq_entries * sizeof(Syscall::IoUringCqe))
  end

  private def sq_entries_size
    LibC::SizeT.new(@params.sq_entries * sizeof(Syscall::IoUringSqe))
  end

  # Data pointed by the `user_data` field
  private struct UserData
    property res = 0
    property fiber = ::Fiber.current
  end

  private def make_timeval(time : ::Time::Span)
    LibC::Timeval.new(
      tv_sec: LibC::TimeT.new(time.total_seconds),
      tv_usec: time.nanoseconds // 1_000
    )
  end

  # Obtains one submission entry, populates, and submits it. When the completion
  # event arrives the current Fiber will be enqueued for execution.
  # The caller of this method MUST either reschedule the current Fiber or
  # resume into another Fiber.
  private def submit!(opcode : Syscall::IoUringOp, user_data_pointer : Pointer(UserData), *, timeval : Pointer(LibC::Timeval) = Pointer(LibC::Timeval).null)
    # Obtains one free index from the submission queue for our use. If there is none
    # available then we should call into the kernel to process what is there. Retry
    # until the kernel has consumed at least one request so that we can write ours.
    until (index = @submission_queue.consume_free_index) != UInt32::MAX
      process_completion_events(blocking: false)
    end

    # The submission queue just stores indices into the `submission_entries` array.
    sqe = @submission_entries + index

    # This submission queue entry is reused! Clean it up.
    Intrinsics.memset(sqe, 0_u8, sizeof(Syscall::IoUringSqe), false)

    # Populate fields and submit the index into the submission queue.
    yield sqe
    sqe.value.user_data = user_data_pointer.address
    sqe.value.opcode = opcode

    # If there is a timeout, we submit a LINK_TIMEOUT as well. It will make the
    # original event fail with ECANCELED if it doesn't complete in time.
    unless timeval.null?
      until (index_timeout = @submission_queue.consume_free_index) != UInt32::MAX
        process_completion_events(blocking: false)
      end

      sqe_timeout = @submission_entries + index_timeout
      Intrinsics.memset(sqe_timeout, 0_u8, sizeof(Syscall::IoUringSqe), false)
      sqe_timeout.value.opcode = Syscall::IoUringOp::LINK_TIMEOUT
      sqe_timeout.value.addr = timeval.address
      sqe_timeout.value.len = 1u32
      sqe.value.flags = sqe.value.flags | Syscall::IoUringSqeFlags::IO_LINK

      @submission_queue.push(index)
      @submission_queue.push(index_timeout)
    else
      @submission_queue.push(index)
    end
  end

  # Safer version of `submit!`, this will block the current fiber until the request completes
  # and will then return the completion result.
  private def submit(opcode : Syscall::IoUringOp, *, timeout : ::Time::Span? = nil)
    user_data = UserData.new
    timeval = make_timeval(timeout || ::Time::Span::ZERO)
    timeval_ptr = timeout ? pointerof(timeval) : Pointer(LibC::Timeval).null
    submit!(opcode, pointerof(user_data), timeval: timeval_ptr) { |sqe| yield sqe }
    sleep # The completion event will wake up this fiber.
    user_data.res
  end

  # Enters the kernel to process events. This can be called either by the event loop when no fiber has
  # work to do (most likely all of them are waiting for completion events) or when the submission queue
  # is full and we are trying to submit more requests. The `blocking` parameter dictates if it should
  # block until at least one completion entry is available or if it should return as soon as possible.
  def process_completion_events(*, blocking = true)
    # Consume available completion events and enqueue their fibers for execution.
    completed_some = false
    @completion_queue.consume_all do |cqe|
      completed_some = true

      # cqe.user_data is zero when this is the completion for a LINK_TIMEOUT event.
      unless cqe.user_data == 0
        # Store result and enqueue the fiber that is waiting for this completion.
        user_data_ptr = Pointer(UserData).new(cqe.user_data)
        user_data_ptr.value.res = cqe.res
        user_data_ptr.value.fiber.enqueue
      end
    end

    # If we consumed at least one event, then there are fibers with work to do.
    return if completed_some && blocking

    # Request the kernel to process events. If we want to block, wait for at least one to complete.
    ret = if blocking
            Syscall.io_uring_enter(@fd, @submission_queue.size, 1, Syscall::IoUringEnterFlags::GETEVENTS, Pointer(LibC::SigsetT).null, 0)
          else
            Syscall.io_uring_enter(@fd, @submission_queue.size, 0, Syscall::IoUringEnterFlags::None, Pointer(LibC::SigsetT).null, 0)
          end

    if ret < 0
      err = Errno.new(-ret)

      # - EINTR indicates that a signal arrived to the current process while it was processing io_uring_enter.
      #   It is safe to try again.
      # - EBUSY indicates that there are so many events being completed right now that the completion queue
      #   is already full and there are more events being stored in a backlog. The is refusing to accept any
      #   new submission until we consume the completion queue. Just repeat and consume it.
      # - EAGAIN indicates that the kernel failed to allocate memory because there are too many inflight requests
      #   for it to keep track and we should retry after some of them have completed. We can retry until it works.
      if err = Errno::EBUSY || err == Errno::EINTR || err == Errno::EAGAIN
        process_completion_events(blocking: blocking)
        return
      end

      # TODO: Trying to print the stack trace will most likely result in infinite recursion. Better abort() here.
      raise RuntimeError.from_os_error("Failed to send submission entries to the kernel", Errno.new(-ret))
    end
  end

  # Represents the lock-free ring queue for submitting requests to the Kernel. It lives in shared memory.
  # The queue actually store indexes into que submission entries array, not managed by this class.
  #
  # The queue has an `@array` of size `@size`. The size is a power of two to make calculations easier.
  # `@mask` is just `@size - 1`, useful to bring a index into the array range.
  #
  # We keep 3 pointers into the queue:
  # - `@tail`: The next item we will write.
  # - `@head`: The next item the Kernel will read, unless it is equal to `@tail`.
  # - `@free`: The next item we can fetch for reuse, unless it is equal to `@head`.
  # All three pointers only move forward increasing by one each time (except for overflow). `@mask` is
  # used on every access to `@array`.
  #
  # `@head` and `@tail` are pointers to where these values are actually stored in shared memory. Only the
  # Kernel updates ´@head.value`, so we must always use ACQUIRE atomics to read from it. Likewise only
  # we update `@tail.value`, so updating it requires RELEASE atomics.
  #
  # `@dropped.value` stores the number of requests the Kernel refused to process because were malformed.
  private struct SubmissionQueue
    @mask : UInt32
    @size : UInt32
    @free : UInt32

    def initialize(@fd : Int32, @base : Void*, offsets : Syscall::IoSqringOffsets)
      @head = Pointer(UInt32).new(base.address + offsets.head)
      @tail = Pointer(UInt32).new(base.address + offsets.tail)
      @mask = Pointer(UInt32).new(base.address + offsets.ring_mask).value
      @size = Pointer(UInt32).new(base.address + offsets.ring_entries).value
      @array = Slice(UInt32).new(Pointer(UInt32).new(base.address + offsets.array), @size)
      @dropped = Pointer(UInt32).new(base.address + offsets.dropped)

      # This begins exactly 1 queue behind head meaning it is all available for reuse.
      @free = (0 - @size).to_u32!

      # Initialize every index. This is required because we fetch from the array for reuse.
      @size.times do |i|
        @array[i] = i
      end

      if @head.value != 0 || @tail.value != 0
        raise RuntimeError.new("SubmissionQueue should start empty")
      end

      if @size != @mask + 1
        raise RuntimeError.new("SubmissionQueue size and mask are mismatched")
      end
    end

    # TODO: Remove it.
    def inspect(io)
      head = Atomic::Ops.load(@head, :acquire, false)
      io << "SubmissionQueue(H: #{head}, T: #{@tail.value}, F: #{@free}, #{size}/#{@size})"
    end

    # Optimistic view of how many itens are queued. As soon as this is computed the Kernel might consume
    # items from one of its threads.
    def size
      @tail.value - Atomic::Ops.load(@head, :acquire, false)
    end

    # Returns the number of requests the Kernel refused to process because were malformed. It should
    # always be zero as there is no way to know which request was dropped. If this is ever not zero,
    # we better abort(). TODO: Check `@dropped`.
    def dropped
      Atomic::Ops.load(@dropped, :acquire, false)
    end

    # Consume one index that is ready for reuse. `UInt32::MAX` means the queue is full.
    def consume_free_index
      head = Atomic::Ops.load(@head, :acquire, false)

      return UInt32::MAX if @free == head

      index = @array[@free & @mask]
      @free &+= 1
      index
    end

    # Writes one request index into the queue.
    def push(index : UInt32)
      # The two operations below are very careful because we must ensure the Kernel sees
      # the array update before it can see the `tail` update. The first write is volatile
      # but not atomic. The second e a volatile atomic release.
      Atomic::Ops.store(@array.@pointer + (@tail.value & @mask), index, :not_atomic, true)
      Atomic::Ops.store(@tail, @tail.value &+ 1, :release, true)
    end
  end

  # Represents the lock-free ring queue for consuming responses from the Kernel. It lives in shared memory.
  #
  # The queue has an `@array` of size `@size`. The size is a power of two to make calculations easier.
  # `@mask` is just `@size - 1`, useful to bring a index into the array range.
  #
  # We keep 2 pointers into the queue:
  # - `@tail`: The next item the Kernel will write.
  # - `@head`: The next item we will read, unless it is equal to `@tail`.
  # Both pointers only move forward increasing by one each time (except for overflow). `@mask` is
  # used on every access to `@array`.
  #
  # `@head` and `@tail` are pointers to where these values are actually stored in shared memory. Only the
  # Kernel updates ´@tail.value`, so we must always use ACQUIRE atomics to read from it. Likewise only
  # we update `@head.value`, so updating it requires RELEASE atomics.
  #
  # `@overflow.value` stores the number of responses the Kernel discarted because there wasn't room in the
  # queue to insert them. Since Linux 5.4 it should be always zero (NODROP feature).
  private struct CompletionQueue
    @mask : UInt32
    @size : UInt32

    def initialize(@fd : Int32, base : Void*, offsets : Syscall::IoCqringOffsets)
      @head = Pointer(UInt32).new(base.address + offsets.head)
      @tail = Pointer(UInt32).new(base.address + offsets.tail)
      @mask = Pointer(UInt32).new(base.address + offsets.ring_mask).value
      @size = Pointer(UInt32).new(base.address + offsets.ring_entries).value
      @array = Slice(Syscall::IoUringCqe).new(Pointer(Syscall::IoUringCqe).new(base.address + offsets.cqes), @size)
      @overflow = Pointer(UInt32).new(base.address + offsets.overflow)

      if @head.value != 0 || @tail.value != 0
        raise RuntimeError.new("CompletionQueue should start empty")
      end

      if @size != @mask + 1
        raise RuntimeError.new("CompletionQueue size and mask are mismatched")
      end
    end

    # TODO: Remove it.
    def inspect(io)
      tail = Atomic::Ops.load(@tail, :acquire, false)
      io << "CompletionQueue(H: #{@head.value}, T: #{tail}, #{size}/#{@size})"
    end

    # Optimistic view of how many itens are queued. As soon as this is computed the Kernel might insert
    # new items from one of its threads.
    def size
      Atomic::Ops.load(@tail, :acquire, false) - @head.value
    end

    # Returns the number of responses the Kernel discarted because there wasn't room in the
    # queue to insert them. Since Linux 5.4 it should be always zero (NODROP feature). If this is
    # not zero, then there is no way to know which event was dropped and we should abort().
    def overflow
      Atomic::Ops.load(@overflow, :acquire, false)
    end

    # Consume and yield each currently available item of the queue, leaving room for the kernel to write.
    def consume_all
      tail = Atomic::Ops.load(@tail, :acquire, false)
      head = @head.value

      return if head == tail

      while head < tail
        yield @array[head & @mask]
        head &+= 1
      end

      Atomic::Ops.store(@head, head, :release, false)
    end
  end

  # Submits a NOP operation. It will complete as soon as possible. Useful for Fiber.yield.
  def nop
    submit :nop do |sqe|
    end
  end

  # Submits a NOP operation and calls the passed-in block. It must suspend the current Fiber.
  def nop!
    user_data = UserData.new
    submit!(:nop, pointerof(user_data)) do |sqe|
    end
    yield
  end

  # Writes a sequence o slices to fd. Each slice is written sequencially starting at `offset` of the file, by default the current position.
  # The entire write is atomic in the sense that it is garanteed that all buffers will be written into the file one after the other
  # even if other process is trying to write to the same file at the same time.
  def writev(fd : Int32, slices : Array(Bytes), offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    iov = slices.map { |slice| Syscall::IOVec.new(slice.to_unsafe, slice.size.to_u64) }
    submit :writev, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = iov.to_unsafe.address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # :ditto:
  def writev(fd : Int32, slices : Tuple(Bytes), offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    iov = slices.map { |slice| Syscall::IOVec.new(slice.to_unsafe, slice.size.to_u64) }
    submit :writev, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = pointerof(iov).address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # Writes a slice of data to fd at the position `offset`, by default the current position.
  def write(fd : Int32, slice : Bytes, offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    if IoUring.probe.operations.write?
      submit :write, timeout: timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = slice.to_unsafe.address
        sqe.value.len = slice.size.to_u
        sqe.value.off = offset
      end
    else
      writev(fd, {slice}, offset, timeout: timeout)
    end
  end

  # Reads a sequence o slices to fd. Each slice is read sequencially starting at `offset` of the file, by default the current position.
  # The entire read is atomic in the sense that it is garanteed that all buffers will be read from the file one after the other
  # even if other process is trying to read to the same file at the same time.
  def readv(fd : Int32, slices : Array(Bytes), offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    iov = slices.map { |slice| Syscall::IOVec.new(slice.to_unsafe, slice.size.to_u64) }
    submit :readv, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = iov.to_unsafe.address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # :ditto:
  def readv(fd : Int32, slices : Tuple(Bytes), offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    iov = slices.map { |slice| Syscall::IOVec.new(slice.to_unsafe, slice.size.to_u64) }
    submit :readv, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = pointerof(iov).address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # Read a slice of data to fd from the position `offset`, by default the current position.
  def read(fd : Int32, slice : Bytes, offset : UInt64 = -1.to_u64!, *, timeout : ::Time::Span? = nil)
    if IoUring.probe.operations.read?
      submit :read, timeout: timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = slice.to_unsafe.address
        sqe.value.len = slice.size.to_u
        sqe.value.off = offset
      end
    else
      readv(fd, {slice}, offset, timeout: timeout)
    end
  end

  def send(fd : Int32, slice : Bytes, *, timeout : ::Time::Span? = nil)
    unless IoUring.probe.operations.send?
      return write(fd, slice, timeout: timeout)
    end

    submit :send, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = slice.to_unsafe.address
      sqe.value.len = slice.size.to_u
    end
  end

  def recv(fd : Int32, slice : Bytes, *, timeout : ::Time::Span? = nil)
    unless IoUring.probe.operations.recv?
      return read(fd, slice, timeout: timeout)
    end

    submit :recv, timeout: timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = slice.to_unsafe.address
      sqe.value.len = slice.size.to_u
    end
  end

  def timeout(time : ::Time::Span)
    unless IoUring.probe.operations.timeout?
      raise RuntimeError.new("IoUring's 'timeout' operation is not supported by current kernel. Needs Linux 5.4 or newer.")
    end

    timeval = make_timeval(time)

    submit :timeout do |sqe|
      sqe.value.addr = pointerof(timeval).address
      sqe.value.len = 1u32
    end
  end

  def accept(fd : Int32, addr : LibC::Sockaddr* = Pointer(LibC::Sockaddr).null, addr_len : LibC::SocklenT* = Pointer(LibC::SocklenT).null, *, timeout : ::Time::Span? = nil)
    unless IoUring.probe.operations.accept?
      raise RuntimeError.new("IoUring's 'accept' operation is not supported by current kernel. Needs Linux 5.5 or newer.")
    end

    submit :accept, timeout: timeout do |sqe|
      sqe.value.addr = addr.address
      sqe.value.off = addr_len.address
      sqe.value.fd = fd
    end
  end

  def connect(fd : Int32, addr : LibC::Sockaddr*, addr_len : Int, *, timeout : ::Time::Span? = nil)
    unless IoUring.probe.operations.connect?
      raise RuntimeError.new("IoUring's 'connect' operation is not supported by current kernel. Needs Linux 5.5 or newer.")
    end

    submit :connect, timeout: timeout do |sqe|
      sqe.value.addr = addr.address
      sqe.value.off = addr_len.to_u64
      sqe.value.fd = fd
    end
  end
end
