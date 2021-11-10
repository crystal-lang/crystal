{% skip_file unless flag?(:linux) %}

require "c/unistd"
require "syscall"

module Crystal::System::Syscall
  ::Syscall.def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : UInt32

  ::Syscall.def_syscall io_uring_setup, Int32, entries : UInt32, params : IoUringParams*
  ::Syscall.def_syscall io_uring_enter, Int32, fd : Int32, to_submit : UInt32, min_complete : UInt32, flags : IoUringEnterFlags, sig : LibC::SigsetT*, sigsz : LibC::SizeT
  ::Syscall.def_syscall io_uring_register, Int32, fd : Int32, op : IoUringRegisterOp, arg : Void*, nr_args : UInt32

  IORING_OFF_SQ_RING = LibC::OffT.new(0)
  IORING_OFF_CQ_RING = LibC::OffT.new(0x8000000)
  IORING_OFF_SQES    = LibC::OffT.new(0x10000000)

  @[Flags]
  enum IoUringFlags : UInt32
    IOPOLL     # io_context is polled
    SQPOLL     # SQ poll thread
    SQ_AFF     # sq_thread_cpu is valid
    CQSIZE     # app   CQ = si_u32e
    CLAMP      # clamp SQ/CQ ring sizes
    ATTACH_WQ  # attach to existing wq
    R_DISABLED # start with ring disabled
  end

  @[Flags]
  enum IoUringEnterFlags
    GETEVENTS
    SQ_WAKEUP
    SQ_WAIT
    EXT_ARG
  end

  @[Flags]
  enum IoUringFeatures : UInt32
    SINGLE_MMAP
    NODROP
    SUBMIT_STABLE
    RW_CUR_POS
    CUR_PERSONALITY
    FAST_POLL
    POLL_32BITS
    SQPOLL_NONFIXED
    EXT_ARG
    NATIVE_WORKERS
  end

  enum IoUringOp : UInt8
    NOP
    READV
    WRITEV
    FSYNC
    READ_FIXED
    WRITE_FIXED
    POLL_ADD
    POLL_REMOVE
    SYNC_FILE_RANGE
    SENDMSG
    RECVMSG
    TIMEOUT
    TIMEOUT_REMOVE
    ACCEPT
    ASYNC_CANCEL
    LINK_TIMEOUT
    CONNECT
    FALLOCATE
    OPENAT
    CLOSE
    FILES_UPDATE
    STATX
    READ
    WRITE
    FADVISE
    MADVISE
    SEND
    RECV
    OPENAT2
    EPOLL_CTL
    SPLICE
    PROVIDE_BUFFERS
    REMOVE_BUFFERS
    TEE
    SHUTDOWN
    RENAMEAT
    UNLINKAT
    MKDIRAT
  end

  @[Flags]
  enum IoUringOpAsFlag : UInt64
    {% for op in IoUringOp.constants %}
        {{ op }}
      {% end %}
  end

  enum IoUringRegisterOp : UInt32
    REGISTER_BUFFERS
    UNREGISTER_BUFFERS
    REGISTER_FILES
    UNREGISTER_FILES
    REGISTER_EVENTFD
    UNREGISTER_EVENTFD
    REGISTER_FILES_UPDATE
    REGISTER_EVENTFD_ASYNC
    REGISTER_PROBE
    REGISTER_PERSONALITY
    UNREGISTER_PERSONALITY
    REGISTER_RESTRICTIONS
    REGISTER_ENABLE_RINGS
  end

  @[Flags]
  enum IoUringSqeFlags : UInt8
    FIXED_FILE    # use fixed fileset
    IO_DRAIN      # issue after inflight IO
    IO_LINK       # links next sqe
    IO_HARDLINK   # like LINK, but stronger
    ASYNC         # always go async
    BUFFER_SELECT # select buffer from sqe->buf_group
  end

  @[Extern]
  struct IoSqringOffsets
    property head = 0u32
    property tail = 0u32
    property ring_mask = 0u32
    property ring_entries = 0u32
    property flags = 0u32
    property dropped = 0u32
    property array = 0u32
    property resv1 = 0u32
    property resv2 = 0u64
  end

  @[Extern]
  struct IoCqringOffsets
    property head = 0u32
    property tail = 0u32
    property ring_mask = 0u32
    property ring_entries = 0u32
    property overflow = 0u32
    property cqes = 0u32
    property flags = 0u32
    property resv1 = 0u32
    property resv2 = 0u64
  end

  @[Extern]
  struct IoUringParams
    property sq_entries = 0u32
    property cq_entries = 0u32
    property flags = IoUringFlags::None
    property sq_thread_cpu = 0u32
    property sq_thread_idle = 0u32
    property features = IoUringFeatures::None
    property wq_fd = 0u32
    property resv = StaticArray(UInt32, 3).new(0)
    property sq_off = IoSqringOffsets.new
    property cq_off = IoCqringOffsets.new
  end

  @[Extern]
  struct IoUringCqe
    property user_data = 0u64 # sqe->data submission passed back
    property res = 0i32       # result code for this event
    property flags = 0u32
  end

  @[Flags]
  enum RwFlag : UInt32
    HIPRI
    DSYNC
    SYNC
    NOWAIT
    APPEND
  end

  @[Flags]
  enum PollEvent : UInt32
    IN     = 0x0001
    PRI    = 0x0002
    OUT    = 0x0004
    ERR    = 0x0008
    HUP    = 0x0010
    NVAL   = 0x0020
    RDNORM = 0x0040
    RDBAND = 0x0080
    WRNORM = 0x0100
    WRBAND = 0x0200
    MSG    = 0x0400
    REMOVE = 0x1000
    RDHUP  = 0x2000
  end

  @[Extern(union: true)]
  struct IoUringSqeInnerFlags
    property rw_flags = RwFlag::None
    property poll_events = PollEvent::None
    # property fsync_flags = 0u32
    # property sync_range_flags = 0u32
    # property msg_flags = 0u32
    # property timeout_flags = 0u32
    # property accept_flags = 0u32
    # property cancel_flags = 0u32
    # property open_flags = 0u32
    # property statx_flags = 0u32
    # property fadvise_advice = 0u32
    # property splice_flags = 0u32
    # property rename_flags = 0u32
    # property unlink_flags = 0u32
  end

  @[Extern]
  struct IoUringSqe
    property opcode = IoUringOp::NOP       # type of operation for this sqe
    property flags = IoUringSqeFlags::None # flags
    property ioprio = 0u16                 # ioprio for the request
    property fd = 0i32                     # file descriptor to do IO on
    property off = 0u64                    # offset into file
    property addr = 0u64                   # pointer to buffer or iovecs
    property len = 0u32                    # buffer size or number of iovecs
    property inner_flags = IoUringSqeInnerFlags.new
    property user_data = 0u64          # data to be passed back at completion time
    property buf_index_or_group = 0u16 # index into fixed buffers, if used, or for grouped buffer selection
    property personality = 0u16
    property splice_fd_in = 0i32
    property pad1 = 0u64
    property pad2 = 0u64
  end

  @[Flags]
  enum IoUringProbeOpFlags : UInt16
    SUPPORTED
  end

  @[Extern]
  struct IoUringProbeOp
    property op = 0u8
    property resv = 0u8
    property flags = IoUringProbeOpFlags::None
    property resv2 = 0u32
  end

  @[Extern]
  struct IoUringProbe(N)
    property last_op = 0u8 # last opcode supported
    property ops_len = 0u8 # length of ops[] array below
    property resv = 0u16
    property resv2 = StaticArray(UInt32, 3).new(0)
    property ops = StaticArray(IoUringProbeOp, N).new(IoUringProbeOp.new)
  end
end
