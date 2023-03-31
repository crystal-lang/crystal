{% skip_file unless flag?(:linux) && !flag?(:interpreted) %}

require "c/unistd"
require "syscall"

module Crystal::System::Syscall
  GRND_NONBLOCK = 1u32

  ::Syscall.def_syscall getrandom, LibC::SSizeT, buf : UInt8*, buflen : LibC::SizeT, flags : UInt32

  ::Syscall.def_syscall io_uring_setup, Int32, entries : UInt32, params : IoUringParams*
  ::Syscall.def_syscall io_uring_enter, Int32, fd : Int32, to_submit : UInt32, min_complete : UInt32, flags : UInt32, sig : LibC::SigsetT*, sigsz : LibC::SizeT
  ::Syscall.def_syscall io_uring_register, Int32, fd : Int32, op : UInt32, arg : Void*, nr_args : UInt32

  IORING_OFF_SQ_RING = LibC::OffT.new(0)
  IORING_OFF_CQ_RING = LibC::OffT.new(0x8000000)
  IORING_OFF_SQES    = LibC::OffT.new(0x10000000)

  IORING_OP_NOP             =  0u8 # Linux 5.1
  IORING_OP_READV           =  1u8 # Linux 5.1
  IORING_OP_WRITEV          =  2u8 # Linux 5.1
  IORING_OP_FSYNC           =  3u8 # Linux 5.1
  IORING_OP_READ_FIXED      =  4u8 # Linux 5.1
  IORING_OP_WRITE_FIXED     =  5u8 # Linux 5.1
  IORING_OP_POLL_ADD        =  6u8 # Linux 5.1
  IORING_OP_POLL_REMOVE     =  7u8 # Linux 5.1
  IORING_OP_SYNC_FILE_RANGE =  8u8 # Linux 5.2
  IORING_OP_SENDMSG         =  9u8 # Linux 5.3
  IORING_OP_RECVMSG         = 10u8 # Linux 5.3
  IORING_OP_TIMEOUT         = 11u8 # Linux 5.4
  IORING_OP_TIMEOUT_REMOVE  = 12u8 # Linux 5.5
  IORING_OP_ACCEPT          = 13u8 # Linux 5.5
  IORING_OP_ASYNC_CANCEL    = 14u8 # Linux 5.5
  IORING_OP_LINK_TIMEOUT    = 15u8 # Linux 5.5
  IORING_OP_CONNECT         = 16u8 # Linux 5.5
  IORING_OP_FALLOCATE       = 17u8 # Linux 5.6
  IORING_OP_OPENAT          = 18u8 # Linux 5.6
  IORING_OP_CLOSE           = 19u8 # Linux 5.6
  IORING_OP_FILES_UPDATE    = 20u8 # Linux 5.6
  IORING_OP_STATX           = 21u8 # Linux 5.6
  IORING_OP_READ            = 22u8 # Linux 5.6
  IORING_OP_WRITE           = 23u8 # Linux 5.6
  IORING_OP_FADVISE         = 24u8 # Linux 5.6
  IORING_OP_MADVISE         = 25u8 # Linux 5.6
  IORING_OP_SEND            = 26u8 # Linux 5.6
  IORING_OP_RECV            = 27u8 # Linux 5.6
  IORING_OP_OPENAT2         = 28u8 # Linux 5.6
  IORING_OP_EPOLL_CTL       = 29u8 # Linux 5.6
  IORING_OP_SPLICE          = 30u8 # Linux 5.7
  IORING_OP_PROVIDE_BUFFERS = 31u8 # Linux 5.7
  IORING_OP_REMOVE_BUFFERS  = 32u8 # Linux 5.7
  IORING_OP_TEE             = 33u8 # Linux 5.8
  IORING_OP_SHUTDOWN        = 34u8 # Linux 5.11
  IORING_OP_RENAMEAT        = 35u8 # Linux 5.11
  IORING_OP_UNLINKAT        = 36u8 # Linux 5.11
  IORING_OP_MKDIRAT         = 37u8 # Linux 5.15
  IORING_OP_SYMLINKAT       = 38u8 # Linux 5.15
  IORING_OP_LINKAT          = 39u8 # Linux 5.15
  IORING_OP_MSG_RING        = 40u8 # Linux 5.18
  IORING_OP_FSETXATTR       = 41u8 # Linux 5.19
  IORING_OP_SETXATTR        = 42u8 # Linux 5.19
  IORING_OP_FGETXATTR       = 43u8 # Linux 5.19
  IORING_OP_GETXATTR        = 44u8 # Linux 5.19
  IORING_OP_SOCKET          = 45u8 # Linux 5.19
  IORING_OP_URING_CMD       = 46u8 # Linux 5.19
  IORING_OP_SEND_ZC         = 47u8 # Linux 6.0
  IORING_OP_SENDMSG_ZC      = 48u8 # Linux 6.0

  # io_uring_enter() flags
  IORING_ENTER_GETEVENTS       = 1u32 << 0 # Linux 5.1
  IORING_ENTER_SQ_WAKEUP       = 1u32 << 1 # Linux 5.1
  IORING_ENTER_SQ_WAIT         = 1u32 << 2 # Linux 5.10
  IORING_ENTER_EXT_ARG         = 1u32 << 3 # Linux 5.11
  IORING_ENTER_REGISTERED_RING = 1u32 << 4 # Linux 5.18

  # io_uring_register() opcodes
  IORING_REGISTER_BUFFERS          =  0u32 # Linux 5.1
  IORING_UNREGISTER_BUFFERS        =  1u32 # Linux 5.1
  IORING_REGISTER_FILES            =  2u32 # Linux 5.1
  IORING_UNREGISTER_FILES          =  3u32 # Linux 5.1
  IORING_REGISTER_EVENTFD          =  4u32 # Linux 5.2
  IORING_UNREGISTER_EVENTFD        =  5u32 # Linux 5.2
  IORING_REGISTER_FILES_UPDATE     =  6u32 # Linux 5.5
  IORING_REGISTER_EVENTFD_ASYNC    =  7u32 # Linux 5.6
  IORING_REGISTER_PROBE            =  8u32 # Linux 5.6
  IORING_REGISTER_PERSONALITY      =  9u32 # Linux 5.6
  IORING_UNREGISTER_PERSONALITY    = 10u32 # Linux 5.6
  IORING_REGISTER_RESTRICTIONS     = 11u32 # Linux 5.10
  IORING_REGISTER_ENABLE_RINGS     = 12u32 # Linux 5.10
  IORING_REGISTER_FILES2           = 13u32 # Linux 5.13
  IORING_REGISTER_FILES_UPDATE2    = 14u32 # Linux 5.13
  IORING_REGISTER_BUFFERS2         = 15u32 # Linux 5.13
  IORING_REGISTER_BUFFERS_UPDATE   = 16u32 # Linux 5.13
  IORING_REGISTER_IOWQ_AFF         = 17u32 # Linux 5.14
  IORING_UNREGISTER_IOWQ_AFF       = 18u32 # Linux 5.14
  IORING_REGISTER_IOWQ_MAX_WORKERS = 19u32 # Linux 5.15
  IORING_REGISTER_RING_FDS         = 20u32 # Linux 5.18
  IORING_UNREGISTER_RING_FDS       = 21u32 # Linux 5.18
  IORING_REGISTER_PBUF_RING        = 22u32 # Linux 5.19
  IORING_UNREGISTER_PBUF_RING      = 23u32 # Linux 5.19
  IORING_REGISTER_SYNC_CANCEL      = 24u32 # Linux 6.0
  IORING_REGISTER_FILE_ALLOC_RANGE = 25u32 # Linux 6.0

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
    property flags = 0u32
    property sq_thread_cpu = 0u32
    property sq_thread_idle = 0u32
    property features = 0u32
    property wq_fd = 0u32
    property resv = StaticArray(UInt32, 3).new(0)
    property sq_off = IoSqringOffsets.new
    property cq_off = IoCqringOffsets.new
  end

  # IoUringParams#flags
  IORING_SETUP_IOPOLL        = 1u32 << 0  # Linux 5.1
  IORING_SETUP_SQPOLL        = 1u32 << 1  # Linux 5.1
  IORING_SETUP_SQ_AFF        = 1u32 << 2  # Linux 5.1
  IORING_SETUP_CQSIZE        = 1u32 << 3  # Linux 5.5
  IORING_SETUP_CLAMP         = 1u32 << 4  # Linux 5.6
  IORING_SETUP_ATTACH_WQ     = 1u32 << 5  # Linux 5.6
  IORING_SETUP_R_DISABLED    = 1u32 << 6  # Linux 5.10
  IORING_SETUP_SUBMIT_ALL    = 1u32 << 7  # Linux 5.18
  IORING_SETUP_COOP_TASKRUN  = 1u32 << 8  # Linux 5.19
  IORING_SETUP_TASKRUN_FLAG  = 1u32 << 9  # Linux 5.19
  IORING_SETUP_SQE128        = 1u32 << 10 # Linux 5.19
  IORING_SETUP_CQE32         = 1u32 << 11 # Linux 5.19
  IORING_SETUP_SINGLE_ISSUER = 1u32 << 12 # Linux 6.0
  IORING_SETUP_DEFER_TASKRUN = 1u32 << 13 # Linux 6.1

  # IoUringParams#features
  IORING_FEAT_SINGLE_MMAP     = 1u32 << 0  # Linux 5.4
  IORING_FEAT_NODROP          = 1u32 << 1  # Linux 5.5
  IORING_FEAT_SUBMIT_STABLE   = 1u32 << 2  # Linux 5.5
  IORING_FEAT_RW_CUR_POS      = 1u32 << 3  # Linux 5.6
  IORING_FEAT_CUR_PERSONALITY = 1u32 << 4  # Linux 5.6
  IORING_FEAT_FAST_POLL       = 1u32 << 5  # Linux 5.7
  IORING_FEAT_POLL_32BITS     = 1u32 << 6  # Linux 5.9
  IORING_FEAT_SQPOLL_NONFIXED = 1u32 << 7  # Linux 5.11
  IORING_FEAT_EXT_ARG         = 1u32 << 8  # Linux 5.11
  IORING_FEAT_NATIVE_WORKERS  = 1u32 << 9  # Linux 5.12
  IORING_FEAT_RSRC_TAGS       = 1u32 << 10 # Linux 5.13
  IORING_FEAT_CQE_SKIP        = 1u32 << 11 # Linux 5.17
  IORING_FEAT_LINKED_FILE     = 1u32 << 12 # Linux 5.18

  @[Extern]
  struct IoUringCqe
    property user_data = 0u64 # sqe->data submission passed back
    property res = 0i32       # result code for this event
    property flags = 0u32
  end

  @[Extern(union: true)]
  struct IoUringSqeInnerFlags
    property rw_flags = 0u32
    property poll_events = 0u32
    property fsync_flags = 0u32
    property sync_range_flags = 0u32
    property msg_flags = 0u32
    property timeout_flags = 0u32
    property accept_flags = 0u32
    property cancel_flags = 0u32
    property open_flags = 0u32
    property statx_flags = 0u32
    property fadvise_advice = 0u32
    property splice_flags = 0u32
    property rename_flags = 0u32
    property unlink_flags = 0u32
    property hardlink_flags = 0u32
    property xattr_flags = 0u32
    property msg_ring_flags = 0u32
    property uring_cmd_flags = 0u32
  end

  # IoUringSqeInnerFlags#poll_events
  POLLIN     = 0x0001u32
  POLLPRI    = 0x0002u32
  POLLOUT    = 0x0004u32
  POLLERR    = 0x0008u32
  POLLHUP    = 0x0010u32
  POLLNVAL   = 0x0020u32
  POLLRDNORM = 0x0040u32
  POLLRDBAND = 0x0080u32
  POLLWRNORM = 0x0100u32
  POLLWRBAND = 0x0200u32
  POLLMSG    = 0x0400u32
  POLLREMOVE = 0x1000u32
  POLLRDHUP  = 0x2000u32

  @[Extern]
  struct IoUringSqe
    property opcode = 0u8  # type of operation for this sqe
    property flags = 0u8   # flags
    property ioprio = 0u16 # ioprio for the request
    property fd = 0i32     # file descriptor to do IO on
    property off = 0u64    # offset into file
    property addr = 0u64   # pointer to buffer or iovecs
    property len = 0u32    # buffer size or number of iovecs
    property inner_flags = IoUringSqeInnerFlags.new
    property user_data = 0u64          # data to be passed back at completion time
    property buf_index_or_group = 0u16 # index into fixed buffers, if used, or for grouped buffer selection
    property personality = 0u16
    property splice_fd_in = 0i32
    property pad1 = 0u64
    property pad2 = 0u64
  end

  # IoUringSqe#flags
  IOSQE_FIXED_FILE       = 1u8 << 0 # use fixed fileset
  IOSQE_IO_DRAIN         = 1u8 << 1 # issue after inflight IO
  IOSQE_IO_LINK          = 1u8 << 2 # links next sqe
  IOSQE_IO_HARDLINK      = 1u8 << 3 # like LINK, but stronger
  IOSQE_ASYNC            = 1u8 << 4 # always go async
  IOSQE_BUFFER_SELECT    = 1u8 << 5 # select buffer from sqe->buf_group
  IOSQE_CQE_SKIP_SUCCESS = 1u8 << 6 # don't post CQE if request succeeded

  @[Extern]
  struct IoUringProbeOp
    property op = 0u8
    property resv = 0u8
    property flags = 0u16
    property resv2 = 0u32
  end

  # IoUringProbeOp#flags
  IO_URING_OP_SUPPORTED = 1u16 << 0

  @[Extern]
  struct IoUringProbe
    property last_op = 0u8 # last opcode supported
    property ops_len = 0u8 # length of ops[] array below
    property resv = 0u16
    property resv2 = StaticArray(UInt32, 3).new(0)
    property ops = StaticArray(IoUringProbeOp, 256).new(IoUringProbeOp.new)
  end
end
