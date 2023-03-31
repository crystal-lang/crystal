require "./syscall"

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
    property features = 0u32
    @operations = StaticArray(Bool, 256).new(false)

    # This method should never raise exceptions
    def initialize
      params = Syscall::IoUringParams.new
      fd = Syscall.io_uring_setup(1, pointerof(params))
      return if fd < 0

      @has_io_uring = true
      @features = params.features

      probe = Syscall::IoUringProbe.new
      ret = Syscall.io_uring_register(fd, Syscall::IORING_REGISTER_PROBE, pointerof(probe).as(Void*), 256)
      LibC.close(fd)
      return if ret < 0

      probe.ops_len.times do |i|
        operation = probe.ops[i]
        if operation.flags & Syscall::IO_URING_OP_SUPPORTED != 0
          @operations[operation.op] = true
        end
      end
    end

    def supports_op?(op : UInt8)
      @operations.unsafe_fetch(op)
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
                  probe.supports_op?(Syscall::IORING_OP_NOP) &&
                  probe.supports_op?(Syscall::IORING_OP_TIMEOUT) &&
                  probe.supports_op?(Syscall::IORING_OP_LINK_TIMEOUT) &&
                  probe.supports_op?(Syscall::IORING_OP_POLL_ADD)
  end

  alias CompletionAction = String | Proc(Int32, Nil)

  # Creates a new io_uring instance with room for at least `sq_entries_hint`. This value is just
  # a hint. It will be rounded up to the nearest power of two and it will max at 32768.
  def initialize(sq_entries_hint : UInt32 = 128)
    @params = Syscall::IoUringParams.new

    @fd = Syscall.io_uring_setup(sq_entries_hint.clamp(16u32, 32768u32), pointerof(@params))

    if @fd < 0
      fatal_error "Failed to create io_uring interface: #{Errno.new(-@fd)}"
    end

    @submission_queue_mmap = Pointer(Void).null
    @completion_queue_mmap = Pointer(Void).null
    @submission_entries = Pointer(Syscall::IoUringSqe).null
    @inflight = 0
    @last_result = 0

    @next_action_id = 1u64
    @completion_actions = {} of UInt64 => CompletionAction
    @submitted_addresses = {} of UInt64 => Void*

    # Since Linux 5.4 both queues can be mapped in a single call to `mmap`.
    if @params.features & Syscall::IORING_FEAT_SINGLE_MMAP != 0
      mem = LibC.mmap(Pointer(Void).null, {sq_size, cq_size}.max,
        LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED | LibC::MAP_POPULATE,
        @fd, Syscall::IORING_OFF_SQ_RING)

      if mem == LibC::MAP_FAILED
        fatal_error "Cannot allocate submission and completion queues: #{Errno.value}"
      end

      @completion_queue_mmap = @submission_queue_mmap = mem
    else
      mem = LibC.mmap(Pointer(Void).null, sq_size,
        LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED | LibC::MAP_POPULATE,
        @fd, Syscall::IORING_OFF_SQ_RING)

      if mem == LibC::MAP_FAILED
        fatal_error "Cannot allocate submission queue: #{Errno.value}"
      end

      @submission_queue_mmap = mem

      mem = LibC.mmap(Pointer(Void).null, cq_size,
        LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED | LibC::MAP_POPULATE,
        @fd, Syscall::IORING_OFF_CQ_RING)

      if mem == LibC::MAP_FAILED
        fatal_error "Cannot allocate completion queue: #{Errno.value}"
      end

      @completion_queue_mmap = mem
    end

    mem = LibC.mmap(Pointer(Void).null, sq_entries_size,
      LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED | LibC::MAP_POPULATE,
      @fd, Syscall::IORING_OFF_SQES)

    if mem == LibC::MAP_FAILED
      fatal_error "Cannot allocate submission entries: #{Errno.value}"
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
      LibC.munmap(@submission_queue_mmap, {sq_size, cq_size}.max)
    end

    if @submission_queue_mmap
      LibC.munmap(@submission_queue_mmap, sq_size)
    end

    if @completion_queue_mmap
      LibC.munmap(@completion_queue_mmap, cq_size)
    end

    if @completion_queue_mmap
      LibC.munmap(@completion_queue_mmap, sq_entries_size)
    end

    if @fd > 0
      LibC.close(@fd)
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

  private def fatal_error(message)
    Crystal::System.print_error "\nFATAL (io_uring): #{message}\n"
    caller.each { |line| Crystal::System.print_error "  from #{line}\n" }
    exit 1
  end

  private def make_timespec64(time : ::Time::Span)
    LibC::Timespec64.new(
      tv_sec: time.to_i,
      tv_usec: time.nanoseconds
    )
  end

  # Obtains one free index from the submission queue for our use. If there is none
  # available then we should call into the kernel to process what is there. Retry
  # until the kernel has consumed at least one request so that we can write ours.
  private def get_free_index : UInt32
    # If there are too many inflight requests, wait for then to complete before sending
    # more. This check is only needed before the NODROP feature was implemented (Linux 5.5+)
    until @params.features & Syscall::IORING_FEAT_NODROP != 0 || @inflight < @params.cq_entries
      process_completion_events(blocking: true)
    end

    loop do
      index = @submission_queue.consume_free_index

      # If the submission queue is full, submit some events.
      if index == UInt32::MAX
        process_completion_events(blocking: false)
        next
      end

      @inflight += 1
      return index
    end
  end

  def register_completion_action(action : CompletionAction) : UInt64
    id = @next_action_id
    @next_action_id += 1
    @completion_actions[id] = action
    id
  end

  def delete_completion_action(id : UInt64) : Nil
    @submitted_addresses.delete(id)
    @completion_actions.delete(id)
  end

  def invoke_completion_action(id : UInt64) : Nil
    @submitted_addresses.delete(id)
    case action = @completion_actions.delete(id)
    when Fiber
      Crystal::Scheduler.enqueue action
    when Proc
      action.call(@last_result)
    end
  end

  # Obtains one submission entry, populates, and submits it. When the completion
  # event arrives the current Fiber will be enqueued for execution.
  # The caller of this method MUST either reschedule the current Fiber or
  # resume into another Fiber.
  private def submit(opcode : UInt8, action_id : UInt64, timeout : ::Time::Span? = nil)
    # The submission queue just stores indices into the `submission_entries` array.
    index = get_free_index
    sqe = @submission_entries + index

    # This submission queue entry is reused! Clean it up.
    Intrinsics.memset(sqe, 0_u8, sizeof(Syscall::IoUringSqe), false)

    # Populate fields and submit the index into the submission queue.
    yield sqe
    sqe.value.user_data = action_id
    sqe.value.opcode = opcode

    @submitted_addresses[action_id] = Pointer(Void).new(sqe.value.addr)

    # If there is a timeout, we submit a LINK_TIMEOUT as well. It will make the
    # original event fail with ECANCELED if it doesn't complete in time.
    # if timeout
    #   sqe.value.flags = sqe.value.flags | Syscall::IOSQE_IO_LINK

    #   timespec = Pointer(LibC::Timespec64).malloc
    #   timespec.value.tv_sec = timeout.to_i
    #   timespec.value.tv_usec = timeout.nanoseconds

    #   index_timeout = get_free_index
    #   sqe_timeout = @submission_entries + index

    #   sqe_timeout.value.addr = timespec.address
    #   sqe_timeout.value.len = 1u32

    #   if IoUring.probe.supports_op? Syscall::IORING_OP_LINK_TIMEOUT
    #     sqe.value.flags = sqe.value.flags | Syscall::IOSQE_IO_LINK
    #     sqe_timeout.value.opcode = Syscall::IORING_OP_LINK_TIMEOUT
    #     timeout_action_id = register_completion_action(->(result : Int32) {})
    #   else
    #     timeout_action_id = register_completion_action(->(result : Int32) {
    #       @last_result = -Errno::ECANCELED.value
    #       invoke_completion_action(action_id)
    #     })
    #     sqe_timeout.value.opcode = Syscall::IORING_OP_TIMEOUT
    #   end

    #   sqe_timeout.value.user_data = timeout_action_id
    #   @submitted_addresses[timeout_action_id] = Pointer(Void).new(sqe_timeout.value.addr)

    #   LibC.printf "%s\n", "Submit #{index} - #{sqe.value.inspect}"
    #   LibC.printf "%s\n", "Submit (timeout) #{index_timeout} - #{sqe_timeout.value.inspect}"

    #   @submission_queue.push(index)
    #   @submission_queue.push(index_timeout)
    # else
    # LibC.printf "%s\n", "Submit #{index} - #{sqe.value.inspect}"
    @submission_queue.push(index)
    # end
  end

  # Enters the kernel to process events. This can be called either by the event loop when no fiber has
  # work to do (most likely all of them are waiting for completion events) or when the submission queue
  # is full and we are trying to submit more requests. The `blocking` parameter dictates if it should
  # block until at least one completion entry is available or if it should return as soon as possible.
  def process_completion_events(*, blocking = true)
    # Consume available completion events and enqueue their fibers for execution.
    completed_some = false
    # @completion_queue.consume_all do |cqe|
    #   LibC.printf "%s\n", "Completion #{cqe.inspect}"
    #   LibC.printf "%s\n", "Completion #{@completion_actions.inspect}"
    #   @inflight -= 1
    #   completed_some = true

    #   @last_result = cqe.res
    #   invoke_completion_action(cqe.user_data)
    #   LibC.printf "%s\n", "Done completion #{cqe.inspect}"
    # end
    while cqe = @completion_queue.pop
      # LibC.printf "%s\n", "Completion #{cqe.inspect}"
      # LibC.printf "%s\n", "Completion #{@completion_actions.inspect}"
      @inflight -= 1
      completed_some = true

      @last_result = cqe.res
      invoke_completion_action(cqe.user_data)
      # LibC.printf "%s\n", "Done completion #{cqe.inspect}"
    end

    # If we consumed at least one event, then there are fibers with work to do.
    return if completed_some && blocking

    # Request the kernel to process events. If we want to block, wait for at least one to complete.
    ret = if blocking
            Syscall.io_uring_enter(@fd, @submission_queue.size, 1, Syscall::IORING_ENTER_GETEVENTS, Pointer(LibC::SigsetT).null, 0)
          else
            Syscall.io_uring_enter(@fd, @submission_queue.size, 0, 0, Pointer(LibC::SigsetT).null, 0)
          end

    if ret < 0
      err = Errno.new(-ret)

      # - EBUSY indicates that there are so many events being completed right now that the completion queue
      #   is already full and there are more events being stored in a backlog. The kernel is refusing to accept
      #   any new submission until we consume the completion queue. Just repeat and consume it.
      # - EINTR indicates that a signal arrived to the current process while it was processing io_uring_enter.
      #   It is safe to try again.
      # - EAGAIN indicates that the kernel failed to allocate memory because there are too many inflight requests
      #   for it to keep track and we should retry after some of them have completed. We can retry until it works.
      if err == Errno::EBUSY || err == Errno::EINTR || err == Errno::EAGAIN
        process_completion_events(blocking: blocking)
        return
      end

      fatal_error "Failed to send submission entries to the kernel: #{Errno.new(-ret)}"
    end

    # Requests are dropped if they are malformed. We never send those. This is a hard error because if we do,
    # then some Fiber will never wake up and the completion event won't ever be sent.
    if @submission_queue.dropped > 0
      fatal_error "Submission queue has dropped entries: #{@submission_queue.dropped}"
    end

    # This is a hard error because if some completion event was dropped, the waiting Fiber will leak.
    # Linux 5.5+ have the NODROP feature and it will never fail to send a completion for a submitted event.
    # For Linux before 5.5 we keep track of the maximum inflight requests and we don't submit above the limit.
    if @completion_queue.overflow > 0
      fatal_error "Completion queue has overflown: #{@submission_queue.dropped}"
    end
  end

  # Represents the lock-free ring queue for submitting requests to the Kernel. It lives in shared memory.
  # The queue actually store indexes into que submission entries array, not managed by this class.
  #
  # The queue has an `@array` of size `@capacity`. The size is a power of two to make calculations easier.
  # `@mask` is just `@capacity - 1`, useful to bring a index into the array range.
  #
  # We keep 3 pointers into the queue:
  # - `@tail`: The next item we will write.
  # - `@head`: The next item the Kernel will read, unless it is equal to `@tail`.
  # - `@free`: The next item we can fetch for reuse, unless it is equal to `@head`.
  # All three pointers only move forward increasing by one each time (except for overflow). `@mask` is
  # used on every access to `@array`. It holds that `@free` <= `@head` <= `@tail`.
  #
  # `@head` and `@tail` are pointers to where these values are actually stored in shared memory. Only the
  # Kernel updates ´@head.value`, so we must always use ACQUIRE atomics to read from it. Likewise only
  # we update `@tail.value`, so updating it requires RELEASE atomics.
  #
  # `@dropped.value` stores the number of requests the Kernel refused to process because were malformed.
  private struct SubmissionQueue
    @mask : UInt32
    @free : UInt32
    getter capacity : UInt32

    def initialize(@fd : Int32, @base : Void*, offsets : Syscall::IoSqringOffsets)
      @head = Pointer(UInt32).new(base.address + offsets.head)
      @tail = Pointer(UInt32).new(base.address + offsets.tail)
      @mask = Pointer(UInt32).new(base.address + offsets.ring_mask).value
      @capacity = Pointer(UInt32).new(base.address + offsets.ring_entries).value
      @array = Slice(UInt32).new(Pointer(UInt32).new(base.address + offsets.array), @capacity)
      @dropped = Pointer(UInt32).new(base.address + offsets.dropped)

      # This begins exactly 1 queue behind head meaning it is all available for reuse.
      @free = (0 - @capacity).to_u32!

      if @head.value != 0 || @tail.value != 0
        raise RuntimeError.new("SubmissionQueue should start empty")
      end

      if @capacity != @mask + 1
        raise RuntimeError.new("SubmissionQueue size and mask are mismatched")
      end
    end

    # Optimistic view of how many itens are queued. As soon as this is computed the Kernel might consume
    # items from one of its threads.
    def size
      @tail.value - Atomic::Ops.load(@head, :acquire, false)
    end

    # Returns the number of requests the Kernel refused to process because were malformed. It should
    # always be zero as there is no way to know which request was dropped. If this is ever not zero,
    # we better abort().
    def dropped
      Atomic::Ops.load(@dropped, :acquire, false)
    end

    # Consume one index that is ready for reuse. `UInt32::MAX` means the queue is full.
    def consume_free_index
      head = Atomic::Ops.load(@head, :acquire, false)

      return UInt32::MAX if @free == head

      index = @free & @mask
      @array[index] = index
      @free &+= 1
      index
    end

    # Writes one request index into the queue.
    def push(index : UInt32)
      # The two operations below are very careful because we must ensure the Kernel sees
      # the array update before it can see the `tail` update. The first write is volatile
      # but not atomic. The second is a volatile atomic release.
      Atomic::Ops.store(@array.@pointer + (@tail.value & @mask), index, :not_atomic, true)
      Atomic::Ops.store(@tail, @tail.value &+ 1, :release, true)
    end
  end

  # Represents the lock-free ring queue for consuming responses from the Kernel. It lives in shared memory.
  #
  # The queue has an `@array` of size `@capacity`. The size is a power of two to make calculations easier.
  # `@mask` is just `@capacity - 1`, useful to bring a index into the array range.
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
  # queue to insert them. Since Linux 5.5 it should be always zero (NODROP feature).
  private struct CompletionQueue
    @mask : UInt32
    @capacity : UInt32

    def initialize(@fd : Int32, base : Void*, offsets : Syscall::IoCqringOffsets)
      @head = Pointer(UInt32).new(base.address + offsets.head)
      @tail = Pointer(UInt32).new(base.address + offsets.tail)
      @mask = Pointer(UInt32).new(base.address + offsets.ring_mask).value
      @capacity = Pointer(UInt32).new(base.address + offsets.ring_entries).value
      @array = Slice(Syscall::IoUringCqe).new(Pointer(Syscall::IoUringCqe).new(base.address + offsets.cqes), @capacity)
      @overflow = Pointer(UInt32).new(base.address + offsets.overflow)

      if @head.value != 0 || @tail.value != 0
        raise RuntimeError.new("CompletionQueue should start empty")
      end

      if @capacity != @mask + 1
        raise RuntimeError.new("CompletionQueue size and mask are mismatched")
      end
    end

    # Optimistic view of how many itens are queued. As soon as this is computed the Kernel might insert
    # new items from one of its threads.
    def size
      Atomic::Ops.load(@tail, :acquire, false) - @head.value
    end

    # Returns the number of responses the Kernel discarted because there wasn't room in the
    # queue to insert them. Since Linux 5.5 it should be always zero (NODROP feature). If this is
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

    def pop
      tail = Atomic::Ops.load(@tail, :acquire, false)
      head = @head.value

      return if head == tail

      cqe = @array[head & @mask]

      Atomic::Ops.store(@head, head &+ 1, :release, false)

      cqe
    end
  end

  # Submits a NOP operation. It will complete as soon as possible. Useful for Fiber.yield.
  def submit_nop(*, action_id : UInt64, timeout : ::Time::Span? = nil)
    submit Syscall::IORING_OP_NOP, action_id, timeout do |sqe|
    end
  end

  # Writes a sequence o slices to fd. Each slice is written sequencially starting at `offset` of the file, by default the current position.
  # The entire write is atomic in the sense that it is garanteed that all buffers will be written into the file one after the other
  # even if other process is trying to write to the same file at the same time.
  def submit_writev(fd : Int32, slices : Array(Bytes), offset : UInt64 = -1.to_u64!, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    iov = slices.map do |slice|
      vec = LibC::IoVec.new
      vec.iov_base = slice.to_unsafe
      vec.iov_len = slice.size.to_u64
      vec
    end

    submit Syscall::IORING_OP_WRITEV, action_id, timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = iov.to_unsafe.address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # Writes a slice of data to fd at the position `offset`, by default the current position.
  def submit_write(fd : Int32, slice : Bytes, offset : UInt64 = -1.to_u64!, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    if IoUring.probe.supports_op? Syscall::IORING_OP_WRITE
      submit Syscall::IORING_OP_WRITE, action_id, timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = slice.to_unsafe.address
        sqe.value.len = slice.size.to_u
        sqe.value.off = offset
      end
    else
      vec = Pointer(LibC::IoVec).malloc
      vec.value.iov_base = slice.to_unsafe
      vec.value.iov_len = slice.size.to_u64

      submit Syscall::IORING_OP_WRITEV, action_id, timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = vec.address
        sqe.value.len = 1u32
        sqe.value.off = offset
      end
    end
  end

  # Reads a sequence o slices to fd. Each slice is read sequencially starting at `offset` of the file, by default the current position.
  # The entire read is atomic in the sense that it is garanteed that all buffers will be read from the file one after the other
  # even if other process is trying to read to the same file at the same time.
  def submit_readv(fd : Int32, slices : Array(Bytes), offset : UInt64 = -1.to_u64!, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    iov = slices.map do |slice|
      vec = LibC::IoVec.new
      vec.iov_base = slice.to_unsafe
      vec.iov_len = slice.size.to_u64
      vec
    end
    submit Syscall::IORING_OP_READV, action_id, timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = iov.to_unsafe.address
      sqe.value.len = slices.size.to_u
      sqe.value.off = offset
    end
  end

  # Read a slice of data to fd from the position `offset`, by default the current position.
  def submit_read(fd : Int32, slice : Bytes, offset : UInt64 = -1.to_u64!, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    if IoUring.probe.supports_op? Syscall::IORING_OP_READ
      submit Syscall::IORING_OP_READ, action_id, timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = slice.to_unsafe.address
        sqe.value.len = slice.size.to_u
        sqe.value.off = offset
      end
    else
      vec = Pointer(LibC::IoVec).malloc
      vec.value.iov_base = slice.to_unsafe
      vec.value.iov_len = slice.size.to_u64

      submit Syscall::IORING_OP_READV, action_id, timeout do |sqe|
        sqe.value.fd = fd
        sqe.value.addr = vec.address
        sqe.value.len = 1u32
        sqe.value.off = offset
      end
    end
  end

  def submit_send(fd : Int32, slice : Bytes, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    unless IoUring.probe.supports_op? Syscall::IORING_OP_SEND
      submit_write(fd, slice, action_id: action_id, timeout: timeout)
      return
    end

    submit Syscall::IORING_OP_SEND, action_id, timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = slice.to_unsafe.address
      sqe.value.len = slice.size.to_u
    end
  end

  def submit_recv(fd : Int32, slice : Bytes, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    unless IoUring.probe.supports_op? Syscall::IORING_OP_RECV
      submit_read(fd, slice, action_id: action_id, timeout: timeout)
      return
    end

    submit Syscall::IORING_OP_RECV, action_id, timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.addr = slice.to_unsafe.address
      sqe.value.len = slice.size.to_u
    end
  end

  def submit_timeout(time : ::Time::Span, *, action_id : UInt64)
    timespec = Pointer(LibC::Timespec64).malloc
    timespec.value.tv_sec = time.to_i
    timespec.value.tv_usec = time.nanoseconds

    submit Syscall::IORING_OP_TIMEOUT, action_id do |sqe|
      sqe.value.addr = timespec.address
      sqe.value.len = 1u32
    end
  end

  def submit_timeout_remove(action_id : UInt64)
    if IoUring.probe.supports_op? Syscall::IORING_OP_TIMEOUT_REMOVE
      submit Syscall::IORING_OP_TIMEOUT_REMOVE, 0 do |sqe|
        sqe.value.addr = action_id
      end
    end
  end

  def submit_accept(fd : Int32, addr : LibC::Sockaddr* = Pointer(LibC::Sockaddr).null, addr_len : LibC::SocklenT* = Pointer(LibC::SocklenT).null, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    unless IoUring.probe.supports_op? Syscall::IORING_OP_ACCEPT
      raise RuntimeError.new("IoUring's 'accept' operation is not supported by current kernel. Needs Linux 5.5 or newer.")
    end

    submit Syscall::IORING_OP_ACCEPT, action_id, timeout do |sqe|
      sqe.value.addr = addr.address
      sqe.value.off = addr_len.address
      sqe.value.fd = fd
    end
  end

  def submit_connect(fd : Int32, addr : LibC::Sockaddr*, addr_len : Int, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    unless IoUring.probe.supports_op? Syscall::IORING_OP_CONNECT
      raise RuntimeError.new("IoUring's 'connect' operation is not supported by current kernel. Needs Linux 5.5 or newer.")
    end

    submit Syscall::IORING_OP_CONNECT, action_id, timeout do |sqe|
      sqe.value.addr = addr.address
      sqe.value.off = addr_len.to_u64
      sqe.value.fd = fd
    end
  end

  def submit_poll_add(fd : Int32, poll_events : UInt32, *, action_id : UInt64, timeout : ::Time::Span? = nil)
    submit Syscall::IORING_OP_POLL_ADD, action_id, timeout do |sqe|
      sqe.value.fd = fd
      sqe.value.inner_flags.poll_events = poll_events
    end
  end
end
