require "c/linux/io_uring"
require "./syscall"
require "./eventfd"

class Crystal::System::IoUring
  @@no_sqarray = true
  @@features : UInt32?
  @@opcodes : Slice(LibC::IoUringProbeOp)?

  class_getter?(supported : Bool) { check_kernel_support? }

  def self.check_kernel_support? : Bool
    # try with "no sqarray" flag first (available since linux 6.6)
    params = LibC::IoUringParams.new
    params.flags = LibC::IORING_SETUP_NO_SQARRAY
    fd = Syscall.io_uring_setup(1_u32, pointerof(params))

    if fd < 0
      return false if fd == -LibC::ENOSYS
      raise RuntimeError.from_os_error("io_uring_setup", Errno.new(-fd)) unless fd == -LibC::EINVAL

      # try again without "no sqarray" flag
      params = LibC::IoUringParams.new
      fd = Syscall.io_uring_setup(1_u32, pointerof(params))
      raise RuntimeError.from_os_error("io_uring_setup", Errno.new(-fd)) if fd < 0
      @@no_sqarray = false
    end

    @@features = params.features

    begin
      probe_sz = sizeof(LibC::IoUringProbe) + LibC::IORING_OP_LAST * sizeof(LibC::IoUringProbeOp)
      probe = GC.malloc(probe_sz).as(LibC::IoUringProbe*)
      raise RuntimeError.from_errno("malloc") unless probe
      LibIntrinsics.memset(probe, 0_u8, probe_sz, false)

      ret = Syscall.io_uring_register(fd, LibC::IORING_REGISTER_PROBE, probe.as(Void*), LibC::IORING_OP_LAST)
      raise RuntimeError.from_os_error("io_uring_register", Errno.new(-ret)) if ret < 0

      @@opcodes = Slice(LibC::IoUringProbeOp).new(probe.value.ops.to_unsafe, LibC::IORING_OP_LAST)
    ensure
      LibC.close(fd) # if fd > 0
    end

    true
  end

  def self.supports_feature?(feature : UInt32) : Bool
    (@@features.not_nil! & feature) == feature
  end

  def self.supports_opcode?(opcode : UInt32) : Bool
    (@@opcodes.not_nil![opcode].flags & LibC::IO_URING_OP_SUPPORTED) == LibC::IO_URING_OP_SUPPORTED
  end

  @fd : Int32
  @flags : UInt32
  @sq_size : UInt32
  @cq_size : UInt32
  @sqes_size : UInt32
  @sq : Void*
  @cq : Void*

  def initialize(sq_entries : UInt32, *, cq_entries : UInt32? = nil, sq_idle : Int32? = nil, wq : IoUring? = nil)
    # setup the ring
    params = LibC::IoUringParams.new
    params.flags |= LibC::IORING_SETUP_NO_SQARRAY if @@no_sqarray
    # params.flags |= LibC::IORING_SETUP_COOP_TASKRUN
    # params.flags |= LibC::IORING_SETUP_TASKRUN_FLAG

    if cq_entries
      params.cq_entries = cq_entries
      params.flags |= LibC::IORING_SETUP_CQSIZE
    end

    if sq_idle
      params.sq_thread_idle = sq_idle
      params.flags |= LibC::IORING_SETUP_SQPOLL
    end

    if wq
      params.wq_fd = wq.fd.to_u32
      params.flags |= LibC::IORING_SETUP_ATTACH_WQ
    end

    @fd = Syscall.io_uring_setup(sq_entries, pointerof(params))
    raise RuntimeError.from_os_error("io_uring_setup", Errno.new(-@fd)) if @fd < 0

    @flags = params.flags

    # determine buffer sizes
    @sq_size = params.@sq_off.array
    if (params.flags & LibC::IORING_SETUP_NO_SQARRAY) == 0
      # legacy: account for SQARRAY ring
      @sq_size += params.sq_entries * sizeof(UInt32)
    end
    @cq_size = params.@cq_off.cqes + params.cq_entries * sizeof(LibC::IoUringCqe)
    @sqes_size = params.sq_entries * sizeof(LibC::IoUringSqe)

    if (params.features & LibC::IORING_FEAT_SINGLE_MMAP) == LibC::IORING_FEAT_SINGLE_MMAP
      # single mmap: keep the largest size
      @sq_size = @cq_size if @cq_size > @sq_size
      @cq_size = @sq_size
    end

    # map the SQ metadata + SQARRAY ring (legacy) + CQ metadata & ring buffer (modern)
    @sq = mmap(@sq_size, LibC::IORING_OFF_SQ_RING) do
      LibC.close(@fd)
    end

    if (params.features & LibC::IORING_FEAT_SINGLE_MMAP) == LibC::IORING_FEAT_SINGLE_MMAP
      @cq = @sq
    else
      # legacy: must separately map the CQ metadata & ring buffer
      @cq = mmap(@cq_size, LibC::IORING_OFF_CQ_RING) do
        LibC.munmap(@sq, @sq_size)
        LibC.close(@fd)
      end
    end

    # map the SQE ring buffer
    @sqes = mmap(@cq_size, LibC::IORING_OFF_SQES) do
      LibC.munmap(@sq, @sq_size)
      LibC.munmap(@cq, @cq_size) unless @cq == @sq
      LibC.close(@fd)
    end.as(LibC::IoUringSqe*)

    # map accessors
    @sq_head    = (@sq + params.@sq_off.head).as(UInt32*)
    @sq_tail    = (@sq + params.@sq_off.tail).as(UInt32*)
    @sq_mask    = (@sq + params.@sq_off.ring_mask).as(UInt32*)
    @sq_entries = (@sq + params.@sq_off.ring_entries).as(UInt32*)
    @sq_flags   = (@sq + params.@sq_off.flags).as(UInt32*)

    @cq_head    = (@cq + params.@cq_off.head).as(UInt32*)
    @cq_tail    = (@cq + params.@cq_off.tail).as(UInt32*)
    @cq_mask    = (@cq + params.@cq_off.ring_mask).as(UInt32*)
    @cq_entries = (@cq + params.@cq_off.ring_entries).as(UInt32*)
    @cqes       = (@cq + params.@cq_off.cqes).as(LibC::IoUringCqe*)

    if (params.flags & LibC::IORING_SETUP_NO_SQARRAY) == 0
      # map SQARRAY to SQE indexes once and for all (no indirection)
      sq_array = (@sq + params.@sq_off.array).as(UInt32*)
      @sq_entries.value.times { |index| sq_array[index] = index }
    end
  end

  def finalize
    close
  end

  private def mmap(size, offset, &) : Void*
    ptr = LibC.mmap(nil, size, LibC::PROT_READ | LibC::PROT_WRITE, LibC::MAP_SHARED | LibC::MAP_POPULATE, @fd, offset)
    if ptr == LibC::MAP_FAILED
      errno = Errno.value
      yield
      raise RuntimeError.from_os_error("mmap", errno)
    end

    {% if flag?(:preview_mt) %}
      # don't bother inheriting mmap on fork: we don't support fork, only
      # fork/exec and we musn't use the evloop after fork before exec
      LibC.madvise(ptr, size, LibC::MADV_DONTFORK)
    {% end %}

    ptr
  end

  def register(opcode : UInt32, arg : Pointer | Nil = nil, arg_sz = 0) : Nil
    argp = arg ? arg.as(Void*) : Pointer(Void).null
    err = Syscall.io_uring_register(@fd, opcode, argp, arg_sz.to_u32)
    raise RuntimeError.from_os_error("io_uring_register", Errno.new(-err)) if err < 0
  end

  def register(@eventfd : EventFD) : Nil
    efd = eventfd.fd
    register(LibC::IORING_REGISTER_EVENTFD, pointerof(efd), 1)
  end

  # Submit exactly +count+ submission queue entries (SQE). Submits them to the
  # kernel when and if needed: no SQPOLL, SQ thread is sleeping, or the SQ is
  # full.
  #
  # WARNING: the yielded pointer is only valid for the duration of the block!
  def submit(count = 1, & : LibC::IoUringSqe* ->) : Nil
    to_submit = 0_u32

    # OPTIMIZE: reading tail probably doesn't need an atomic
    tail = Atomic::Ops.load(@sq_tail, :monotonic, volatile: true)

    count.times do |i|
      head = Atomic::Ops.load(@sq_head, :acquire, volatile: true)
      size = tail &- head

      if size >= @sq_entries.value
        # SQ ring is full: submit pending SQE and wait for a slot
        if i > 0
          # make the new tail + writes to SQE visible to the kernel
          Atomic::Ops.store(@sq_tail, tail, :release, volatile: true)
          to_submit = 0_u32
        end

        # force submit, wake SQ thread if sleeping, and wait for at least one
        # slot to become available
        flags = 0_u32
        if sq_poll?
          flags |= LibC::IORING_ENTER_SQ_WAIT # wait until one SQE is available
          flags |= LibC::IORING_ENTER_SQ_WAKEUP if sq_need_wakeup?
        end
        enter(to_submit, flags: flags)
      end

      # populate the io_uring_sqe*
      sq_index = tail & @sq_mask.value
      sqe = @sqes.as(LibC::IoUringSqe*) + sq_index
      LibIntrinsics.memset(sqe, 0_u8, sizeof(LibC::IoUringSqe*), false)
      yield sqe

      tail &+= 1_u32
      to_submit += 1_u32
    end

    # make the new tail + writes to SQE visible to the kernel
    Atomic::Ops.store(@sq_tail, tail, :release, volatile: true)

    if sq_poll?
      enter(to_submit, flags: LibC::IORING_ENTER_SQ_WAKEUP) if sq_need_wakeup?
    else
      enter(to_submit)
    end
  end

  private def sq_poll?
    (@flags & LibC::IORING_SETUP_SQPOLL) == LibC::IORING_SETUP_SQPOLL
  end

  private def sq_need_wakeup?
    sq_flags = Atomic::Ops.load(@sq_flags, :acquire, volatile: true)
    (sq_flags & LibC::IORING_SQ_NEED_WAKEUP) == LibC::IORING_SQ_NEED_WAKEUP
  end

  # Iterates ready Completion Queue Entries (CQE).
  #
  # WARNING: the yielded pointer is only valid for the duration of the block!
  def each_completed(& : LibC::IoUringCqe* ->) : Nil
    head = Atomic::Ops.load(@cq_head, :monotonic, volatile: true)
    tail = Atomic::Ops.load(@cq_tail, :acquire, volatile: true)
    return if head == tail

    until head == tail
      yield @cqes + (head & @cq_mask.value)
      head &+= 1
    end

    # make new head visible to the kernel
    Atomic::Ops.store(@cq_head, head, :release, volatile: true)
  end

  def enter(to_submit : UInt32 = 0_u32, to_complete = 0_u32, flags = 0_u32)
    err = Syscall.io_uring_enter(@fd, to_submit.to_u32, to_complete.to_u32, flags, Pointer(Void).null, LibC::SizeT.zero)
    raise RuntimeError.from_os_error("io_uring_enter", Errno.new(-err)) if err < 0
  end

  def close : Nil
    return if (fd = @fd) == -1
    return unless Atomic::Ops.cmpxchg(pointerof(@fd), fd, -1, :acquire, :monotonic).last

    LibC.munmap(@sq, @sq_size)
    LibC.munmap(@cq, @cq_size) unless @cq == @sq
    LibC.munmap(@sqes, @sqes_size)

    LibC.close(fd)
    @eventfd.try(&.close)
  end
end
