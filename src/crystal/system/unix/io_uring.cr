require "c/linux/io_uring"
require "./syscall"

# WARNING: while the syscalls are thread safe, the rings and the overall
# abstraction are not: accesses to the SQ and CQ rings aren't synchronized!
#
# You can, however, use one mutex to synchronize writes to the SQ ring from
# different threads, and another mutex to synchronize reads from the CQ ring.

class Crystal::System::IoUring
  @@no_sqarray = true
  @@features : UInt32?
  @@opcodes : Slice(LibC::IoUringProbeOp)?

  class_getter?(supported : Bool) { check_kernel_support? }
  class_getter? supports_register_send_msg_ring : Bool = false
  class_getter? supports_register_sync_cancel : Bool = false

  def self.check_kernel_support? : Bool
    # try with "no sqarray" flag first (Linux 6.6+)
    params = LibC::IoUringParams.new
    params.flags = LibC::IORING_SETUP_NO_SQARRAY
    fd = Syscall.io_uring_setup(1_u32, pointerof(params))

    if fd < 0
      case -fd
      when LibC::ENOSYS || LibC::EPERM
        # not supported
        return false
      when LibC::EINVAL
        # retry without "no sqarray" flag
        params = LibC::IoUringParams.new
        fd = Syscall.io_uring_setup(1_u32, pointerof(params))
      end

      if fd < 0
        raise RuntimeError.from_os_error("io_uring_setup", Errno.new(-fd))
      end

      @@no_sqarray = false
    end

    # record supported features
    @@features = params.features

    begin
      # probe supported opcodes
      probe_sz = sizeof(LibC::IoUringProbe) + LibC::IORING_OP_LAST * sizeof(LibC::IoUringProbeOp)
      probe = GC.malloc_atomic(probe_sz).as(LibC::IoUringProbe*)
      raise RuntimeError.from_errno("malloc") unless probe
      LibIntrinsics.memset(probe, 0_u8, probe_sz, false)

      ret = Syscall.io_uring_register(fd, LibC::IORING_REGISTER_PROBE, probe.as(Void*), LibC::IORING_OP_LAST)
      raise RuntimeError.from_os_error("io_uring_register", Errno.new(-ret)) if ret < 0

      @@opcodes = Slice(LibC::IoUringProbeOp).new(probe.value.ops.to_unsafe, LibC::IORING_OP_LAST)

      # probe supported register opcodes (must test one by one)
      sqe = LibC::IoUringSqe.new
      sqe.opcode = LibC::IORING_OP_MSG_RING
      sqe.fd = fd
      ret = System::Syscall.io_uring_register(-1, LibC::IORING_REGISTER_SEND_MSG_RING, pointerof(sqe).as(Void*), 1)
      @@supports_register_send_msg_ring = ret == 0

      reg = LibC::IoUringSyncCancelReg.new
      reg.flags = LibC::IORING_ASYNC_CANCEL_FD
      reg.fd = 1
      ret = System::Syscall.io_uring_register(fd, LibC::IORING_REGISTER_SYNC_CANCEL, pointerof(reg).as(Void*), 1)
      @@supports_register_sync_cancel = ret != -LibC::ENOENT
    ensure
      LibC.close(fd)
    end

    true
  end

  def self.supports_feature?(feature : UInt32) : Bool
    (@@features.not_nil! & feature) == feature
  end

  def self.supports_opcode?(opcode : UInt32) : Bool
    (@@opcodes.not_nil![opcode].flags & LibC::IO_URING_OP_SUPPORTED) == LibC::IO_URING_OP_SUPPORTED
  end

  getter fd : Int32
  @flags : UInt32
  @sq_size : UInt32
  @cq_size : UInt32
  @sqes_size : UInt32

  @sq : Void*
  @cq : Void*

  def initialize(sq_entries : Int, *, cq_entries : Int? = nil, sq_thread_idle : Int? = nil, wq_fd : Int? = nil)
    # setup the ring
    params = LibC::IoUringParams.new
    params.flags |= LibC::IORING_SETUP_NO_SQARRAY if @@no_sqarray
    params.flags |= LibC::IORING_SETUP_COOP_TASKRUN

    if cq_entries
      params.cq_entries = cq_entries.to_u32
      params.flags |= LibC::IORING_SETUP_CQSIZE
    end

    if sq_thread_idle
      params.sq_thread_idle = sq_thread_idle.to_i32
      params.flags |= LibC::IORING_SETUP_SQPOLL
    end

    if wq_fd
      params.wq_fd = wq_fd.to_u32
      params.flags |= LibC::IORING_SETUP_ATTACH_WQ
    end

    # The following is boilerplate code to map the rings from kernel land to
    # user land, with some slight differences based on the running kernel
    # supported features (for example single mmap, no SQ array).

    Crystal.trace :evloop, "io_uring_setup"
    @fd = Syscall.io_uring_setup(sq_entries.to_u32, pointerof(params))
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
    @sq_khead = (@sq + params.@sq_off.head).as(UInt32*)
    @sq_ktail = (@sq + params.@sq_off.tail).as(UInt32*)
    @sq_mask = (@sq + params.@sq_off.ring_mask).as(UInt32*)
    @sq_entries = (@sq + params.@sq_off.ring_entries).as(UInt32*)
    @sq_flags = (@sq + params.@sq_off.flags).as(UInt32*)

    @cq_khead = (@cq + params.@cq_off.head).as(UInt32*)
    @cq_ktail = (@cq + params.@cq_off.tail).as(UInt32*)
    @cq_mask = (@cq + params.@cq_off.ring_mask).as(UInt32*)
    @cq_entries = (@cq + params.@cq_off.ring_entries).as(UInt32*)
    @cqes = (@cq + params.@cq_off.cqes).as(LibC::IoUringCqe*)

    if (params.flags & LibC::IORING_SETUP_NO_SQARRAY) == 0
      # map SQARRAY to SQE indexes once and for all (no indirection)
      sq_array = (@sq + params.@sq_off.array).as(UInt32*)
      @sq_entries.value.times { |index| sq_array[index] = index }
    end

    # the current sq tail, synchronized with @sq_ktail on submit
    @sq_tail = 0_u32
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

  def finalize
    close
  end

  # Closes the ring fd. Unmaps the ring buffers.
  def close : Nil
    return if (fd = @fd) == -1
    return unless Atomic::Ops.cmpxchg(pointerof(@fd), fd, -1, :acquire, :monotonic).last

    LibC.munmap(@sq, @sq_size)
    LibC.munmap(@cq, @cq_size) unless @cq == @sq
    LibC.munmap(@sqes, @sqes_size)

    LibC.close(fd)
  end

  def sq_poll? : Bool
    (@flags & LibC::IORING_SETUP_SQPOLL) == LibC::IORING_SETUP_SQPOLL
  end

  def sq_need_wakeup? : Bool
    sq_flags = Atomic::Ops.load(@sq_flags, :monotonic, volatile: true)
    (sq_flags & LibC::IORING_SQ_NEED_WAKEUP) == LibC::IORING_SQ_NEED_WAKEUP
  end

  # Call `io_uring_register` syscall. Raises on error.
  def register(opcode : UInt32, arg : Pointer = Pointer(Void).null, arg_sz = 0) : Nil
    if errno = register?(opcode, arg, arg_sz)
      raise RuntimeError.from_os_error("io_uring_register", errno)
    end
  end

  # Call `io_uring_register` syscall. Returns Errno on error.
  def register?(opcode : UInt32, arg : Pointer = Pointer(Void).null, arg_sz = 0) : Errno?
    err = Syscall.io_uring_register(@fd, opcode, arg.as(Void*), arg_sz.to_u32)
    Errno.new(-err) if err < 0
  end

  # Makes sure there is at least *count* SQE available in the SQ ring so we can
  # submit a chain of SQE at once. Submits pending SQE and waits if needed.
  def reserve(count : Int32) : Nil
    if count > @sq_entries.value
      raise ArgumentError.new("Can't reserve more SQE than available in the SQ ring")
    end

    loop do
      head = Atomic::Ops.load(@sq_khead, :monotonic, volatile: true)
      size = @sq_tail &- head

      if (@sq_entries.value - size) >= count
        break
      else
        submit(wait: true)
      end
    end
  end

  # Reserves a slot and returns the next SQE slot in the SQ ring. Submits
  # pending submissions and waits if the ring is full.
  def next_sqe : LibC::IoUringSqe*
    reserve(1)
    unsafe_next_sqe
  end

  # WARNING: must call `#reserve` before calling `#unsafe_next_sqe`!
  def unsafe_next_sqe : LibC::IoUringSqe*
    index = @sq_tail & @sq_mask.value
    @sq_tail &+= 1

    sqe = @sqes.as(LibC::IoUringSqe*) + index
    LibIntrinsics.memset(sqe, 0_u8, sizeof(LibC::IoUringSqe), false)

    sqe
  end

  # Submit pending SQE in the SQ ring if needed. Wake SQPOLL thread if sleeping.
  # Blocks until at least one SQE becomes available when *wait* is true.
  def submit(flags : UInt32 = 0_u32, wait : Bool = false)
    # make new tail and previous writes visible to the kernel threads
    Atomic::Ops.store(@sq_ktail, @sq_tail, :sequentially_consistent, volatile: true)

    loop do
      if sq_poll?
        if wait
          flags |= LibC::IORING_ENTER_SQ_WAIT
        elsif sq_need_wakeup?
          flags |= LibC::IORING_ENTER_SQ_WAKEUP
        else
          return
        end
      end

      head = Atomic::Ops.load(@sq_khead, :monotonic, volatile: true)
      to_submit = @sq_tail &- head

      ret = enter(to_submit, flags: flags)
      break unless ret == -LibC::EINTR
    end
  end

  # Call `io_uring_enter` syscall. Panics on EBADR (can't recover from lost
  # CQE), returns -EINTR, -ETIME or -EBUSY, and raises on other errnos,
  # otherwise returns the value returned by the syscall.
  def enter(to_submit : Int = 0, min_complete : Int = 0, flags : UInt32 = 0, timeout : ::Time::Span? = nil) : Int32
    if timeout
      flags |= LibC::IORING_ENTER_EXT_ARG

      ts = uninitialized LibC::Timespec
      ts.tv_sec = typeof(ts.tv_sec).new(timeout.@seconds)
      ts.tv_nsec = typeof(ts.tv_nsec).new(timeout.@nanoseconds)

      args = LibC::IoUringGetEventsArg.new(ts: pointerof(ts).address.to_u64!)
      arg = pointerof(args).as(Void*)
      argsz = LibC::SizeT.new(sizeof(LibC::IoUringGetEventsArg))
    else
      arg = Pointer(Void).null
      argsz = LibC::SizeT.zero
    end

    Crystal.trace :evloop, "io_uring_enter",
      fd: @fd,
      to_submit: to_submit,
      min_complete: min_complete,
      timeout: timeout,
      flags: ENTER.new(flags).to_s

    ret = Syscall.io_uring_enter(@fd, to_submit.to_u32, min_complete.to_u32, flags, arg, argsz)
    return ret if ret >= 0

    case ret
    when -LibC::EINTR, -LibC::ETIME
      # interrupted by signal (caller shall retry) or timeout expired
      ret
    when -LibC::EBUSY
      # the CQ ring is full and the kernel has overflow CQE waiting
      # TODO: set a boolean so the next evloop run can process has many CQEs as
      # possible until max iterations or the CQ ring is emptied
      ret
    when -LibC::EBADR
      # CQE ring buffer overflowed, the system is running low on memory and
      # completion entries got dropped despite of IORING_FEAT_NODROP and we
      # can't recover from lost completions as fibers would never be resumed!
      System.panic("io_uring_enter", Errno.new(-ret))
    else
      raise RuntimeError.from_os_error("io_uring_enter", Errno.new(-ret))
    end
  end

  # Iterates ready Completion Queue Entries (CQE).
  #
  # WARNING: the yielded pointer is only valid for the duration of the block!
  def each_completed(& : LibC::IoUringCqe* ->) : Nil
    head = Atomic::Ops.load(@cq_khead, :acquire, volatile: true)
    tail = Atomic::Ops.load(@cq_ktail, :monotonic, volatile: true)
    return if head == tail

    until head == tail
      yield @cqes + (head & @cq_mask.value)
      head &+= 1

      # TODO: we could update @cq_khead on each iteration, but we'd need a
      # maximum iterations count so we don't iterate ad infinitum
    end

    # report to kernel we've seen the CQEs
    Atomic::Ops.store(@cq_khead, head, :release, volatile: true)

    # TODO: we could check if tail changed and iterate more, until we reach the
    # maximum iterations count
  end

  def self.trace(sqe : LibC::IoUringSqe*)
    Crystal.trace :evloop, "sqe",
      user_data: Pointer(Void).new(sqe.value.user_data),
      opcode: OPCODE.new(sqe.value.opcode).to_s,
      flags: IOSQE.new(sqe.value.flags).to_s,
      fd: sqe.value.fd,
      addr: Pointer(Void).new(sqe.value.addr),
      len: sqe.value.len
    # LibC.dprintf(2, sqe.value.pretty_inspect)
  end

  def self.trace(cqe : LibC::IoUringCqe*)
    Crystal.trace :evloop, "cqe",
      user_data: Pointer(Void).new(cqe.value.user_data),
      res: cqe.value.res >= 0 ? cqe.value.res : Errno.new(-cqe.value.res).to_s,
      flags: cqe.value.flags
  end

  # The following enums are only used for tracing:

  @[Flags]
  enum IOSQE : UInt32
    IOSQE_IO_DRAIN = LibC::IOSQE_IO_DRAIN
    IOSQE_IO_LINK  = LibC::IOSQE_IO_LINK
  end

  enum ENTER : UInt32
    IORING_ENTER_GETEVENTS = LibC::IORING_ENTER_GETEVENTS
    IORING_ENTER_SQ_WAKEUP = LibC::IORING_ENTER_SQ_WAKEUP
    IORING_ENTER_SQ_WAIT   = LibC::IORING_ENTER_SQ_WAIT
    IORING_ENTER_EXT_ARG   = LibC::IORING_ENTER_EXT_ARG
  end

  enum OPCODE : UInt32
    IORING_OP_NOP              = LibC::IORING_OP_NOP
    IORING_OP_READV            = LibC::IORING_OP_READV
    IORING_OP_WRITEV           = LibC::IORING_OP_WRITEV
    IORING_OP_FSYNC            = LibC::IORING_OP_FSYNC
    IORING_OP_READ_FIXED       = LibC::IORING_OP_READ_FIXED
    IORING_OP_WRITE_FIXED      = LibC::IORING_OP_WRITE_FIXED
    IORING_OP_POLL_ADD         = LibC::IORING_OP_POLL_ADD
    IORING_OP_POLL_REMOVE      = LibC::IORING_OP_POLL_REMOVE
    IORING_OP_SYNC_FILE_RANGE  = LibC::IORING_OP_SYNC_FILE_RANGE
    IORING_OP_SENDMSG          = LibC::IORING_OP_SENDMSG
    IORING_OP_RECVMSG          = LibC::IORING_OP_RECVMSG
    IORING_OP_TIMEOUT          = LibC::IORING_OP_TIMEOUT
    IORING_OP_TIMEOUT_REMOVE   = LibC::IORING_OP_TIMEOUT_REMOVE
    IORING_OP_ACCEPT           = LibC::IORING_OP_ACCEPT
    IORING_OP_ASYNC_CANCEL     = LibC::IORING_OP_ASYNC_CANCEL
    IORING_OP_LINK_TIMEOUT     = LibC::IORING_OP_LINK_TIMEOUT
    IORING_OP_CONNECT          = LibC::IORING_OP_CONNECT
    IORING_OP_FALLOCATE        = LibC::IORING_OP_FALLOCATE
    IORING_OP_OPENAT           = LibC::IORING_OP_OPENAT
    IORING_OP_CLOSE            = LibC::IORING_OP_CLOSE
    IORING_OP_FILES_UPDATE     = LibC::IORING_OP_FILES_UPDATE
    IORING_OP_STATX            = LibC::IORING_OP_STATX
    IORING_OP_READ             = LibC::IORING_OP_READ
    IORING_OP_WRITE            = LibC::IORING_OP_WRITE
    IORING_OP_FADVISE          = LibC::IORING_OP_FADVISE
    IORING_OP_MADVISE          = LibC::IORING_OP_MADVISE
    IORING_OP_SEND             = LibC::IORING_OP_SEND
    IORING_OP_RECV             = LibC::IORING_OP_RECV
    IORING_OP_OPENAT2          = LibC::IORING_OP_OPENAT2
    IORING_OP_EPOLL_CTL        = LibC::IORING_OP_EPOLL_CTL
    IORING_OP_SPLICE           = LibC::IORING_OP_SPLICE
    IORING_OP_PROVIDE_BUFFERS  = LibC::IORING_OP_PROVIDE_BUFFERS
    IORING_OP_REMOVE_BUFFERS   = LibC::IORING_OP_REMOVE_BUFFERS
    IORING_OP_TEE              = LibC::IORING_OP_TEE
    IORING_OP_SHUTDOWN         = LibC::IORING_OP_SHUTDOWN
    IORING_OP_RENAMEAT         = LibC::IORING_OP_RENAMEAT
    IORING_OP_UNLINKAT         = LibC::IORING_OP_UNLINKAT
    IORING_OP_MKDIRAT          = LibC::IORING_OP_MKDIRAT
    IORING_OP_SYMLINKAT        = LibC::IORING_OP_SYMLINKAT
    IORING_OP_LINKAT           = LibC::IORING_OP_LINKAT
    IORING_OP_MSG_RING         = LibC::IORING_OP_MSG_RING
    IORING_OP_FSETXATTR        = LibC::IORING_OP_FSETXATTR
    IORING_OP_SETXATTR         = LibC::IORING_OP_SETXATTR
    IORING_OP_FGETXATTR        = LibC::IORING_OP_FGETXATTR
    IORING_OP_GETXATTR         = LibC::IORING_OP_GETXATTR
    IORING_OP_SOCKET           = LibC::IORING_OP_SOCKET
    IORING_OP_URING_CMD        = LibC::IORING_OP_URING_CMD
    IORING_OP_SEND_ZC          = LibC::IORING_OP_SEND_ZC
    IORING_OP_SENDMSG_ZC       = LibC::IORING_OP_SENDMSG_ZC
    IORING_OP_READ_MULTISHOT   = LibC::IORING_OP_READ_MULTISHOT
    IORING_OP_WAITID           = LibC::IORING_OP_WAITID
    IORING_OP_FUTEX_WAIT       = LibC::IORING_OP_FUTEX_WAIT
    IORING_OP_FUTEX_WAKE       = LibC::IORING_OP_FUTEX_WAKE
    IORING_OP_FUTEX_WAITV      = LibC::IORING_OP_FUTEX_WAITV
    IORING_OP_FIXED_FD_INSTALL = LibC::IORING_OP_FIXED_FD_INSTALL
    IORING_OP_FTRUNCATE        = LibC::IORING_OP_FTRUNCATE
    IORING_OP_BIND             = LibC::IORING_OP_BIND
    IORING_OP_LISTEN           = LibC::IORING_OP_LISTEN
    IORING_OP_LAST             = LibC::IORING_OP_LAST
  end
end
