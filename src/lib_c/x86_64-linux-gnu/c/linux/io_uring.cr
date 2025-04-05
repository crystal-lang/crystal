lib LibC
  # IORING_FILE_INDEX_ALLOC = ~0_u32

  IOSQE_FIXED_FILE       = 1_u32 << 0
  IOSQE_IO_DRAIN         = 1_u32 << 1
  IOSQE_IO_LINK          = 1_u32 << 2
  IOSQE_IO_HARDLINK      = 1_u32 << 3
  IOSQE_ASYNC            = 1_u32 << 4
  IOSQE_BUFFER_SELECT    = 1_u32 << 5
  IOSQE_CQE_SKIP_SUCCESS = 1_u32 << 6

  # IORING_SETUP_IOPOLL = 1_u32 << 0
  IORING_SETUP_SQPOLL = 1_u32 << 1
  # IORING_SETUP_SQ_AFF = 1_u32 << 2
  IORING_SETUP_CQSIZE = 1_u32 << 3
  # IORING_SETUP_CLAMP = 1_u32 << 4
  IORING_SETUP_ATTACH_WQ = 1_u32 << 5
  # IORING_SETUP_R_DISABLED = 1_u32 << 6
  # IORING_SETUP_SUBMIT_ALL = 1_u32 << 7
  IORING_SETUP_COOP_TASKRUN = 1_u32 << 8
  IORING_SETUP_TASKRUN_FLAG = 1_u32 << 9
  # IORING_SETUP_SQE128 = 	1_u32 << 10
  # IORING_SETUP_CQE32 = 	1_u32 << 11
  # IORING_SETUP_SINGLE_ISSUER = 1_u32 << 12
  # IORING_SETUP_DEFER_TASKRUN = 1_u32 << 13
  # IORING_SETUP_NO_MMAP = 	1_u32 << 14
  # IORING_SETUP_REGISTERED_FD_ONLY = 1_u32 << 15
  IORING_SETUP_NO_SQARRAY = 1_u32 << 16

  # IORING_TIMEOUT_ABS = 1_u32 << 0
  # IORING_TIMEOUT_UPDATE = 1_u32 << 1
  # IORING_TIMEOUT_BOOTTIME = 1_u32 << 2
  # IORING_TIMEOUT_REALTIME = 1_u32 << 3
  # IORING_LINK_TIMEOUT_UPDATE = 1_u32 << 4
  # IORING_TIMEOUT_ETIME_SUCCESS = 1_u32 << 5
  # IORING_TIMEOUT_MULTISHOT = 1_u32 << 6
  # IORING_TIMEOUT_CLOCK_MASK = IORING_TIMEOUT_BOOTTIME | IORING_TIMEOUT_REALTIME
  # IORING_TIMEOUT_UPDATE_MASK = IORING_TIMEOUT_UPDATE | IORING_LINK_TIMEOUT_UPDATE

  IORING_SQ_NEED_WAKEUP = 1_u32 << 0
  # IORING_SQ_CQ_OVERFLOW = 1_u32 << 1
  IORING_SQ_TASKRUN = 1_u32 << 2

  # IORING_CQ_EVENTFD_DISABLED = 1_u32 << 0

  IORING_ENTER_GETEVENTS       = 1_u32 << 0
  IORING_ENTER_SQ_WAKEUP       = 1_u32 << 1
  IORING_ENTER_SQ_WAIT         = 1_u32 << 2
  IORING_ENTER_EXT_ARG         = 1_u32 << 3
  IORING_ENTER_REGISTERED_RING = 1_u32 << 4

  IORING_ASYNC_CANCEL_ALL = 1_u32 << 0
  IORING_ASYNC_CANCEL_FD  = 1_u32 << 1

  # IORING_ASYNC_CANCEL_ANY = 1_u32 << 2
  # IORING_ASYNC_CANCEL_FD_FIXED = 1_u32 << 3
  # IORING_ASYNC_CANCEL_USERDATA = 1_u32 << 4
  # IORING_ASYNC_CANCEL_OP = 1_u32 << 5

  union IoUringSqeU1
    off : UInt64
    addr2 : UInt64
  end

  union IoUringSqeFlags
    rw_flags : Int32
    fsync_flags : UInt32
    poll_events : UInt16
    poll32_events : UInt32
    sync_range_flags : UInt32
    msg_flags : UInt32
    timeout_flags : UInt32
    accept_flags : UInt32
    cancel_flags : UInt32
    open_flags : UInt32
    statx_flags : UInt32
    fadvise_advice : UInt32
    splice_flags : UInt32
    rename_flags : UInt32
    unlink_flags : UInt32
    hardlink_flags : UInt32
    xattr_flags : UInt32
    msg_ring_flags : UInt32
    uring_cmd_flags : UInt32
    waitid_flags : UInt32
    futex_flags : UInt32
    install_fd_flags : UInt32
    nop_flags : UInt32
  end

  struct IoUringSqe
    opcode : UInt8
    flags : UInt8
    ioprio : UInt16
    fd : Int32
    u1 : IoUringSqeU1
    addr : UInt64
    len : UInt32
    sflags : IoUringSqeFlags
    user_data : UInt64
    buf_index : UInt16
    personality : UInt16
    addr_len : UInt16[2]
    addr3 : UInt64
    __pad2 : UInt64[1]
  end

  struct IoUringCqe
    user_data : UInt64
    res : Int32
    flags : UInt32
  end

  struct IoSqringOffsets
    head : UInt32
    tail : UInt32
    ring_mask : UInt32
    ring_entries : UInt32
    flags : UInt32
    dropped : UInt32
    array : UInt32
    resv1 : UInt32
    user_addr : UInt64
  end

  struct IoCqringOffsets
    head : UInt32
    tail : UInt32
    ring_mask : UInt32
    ring_entries : UInt32
    overflow : UInt32
    cqes : UInt32
    flags : UInt32
    resv1 : UInt32
    user_addr : UInt64
  end

  struct IoUringParams
    sq_entries : UInt32
    cq_entries : UInt32
    flags : UInt32
    sq_thread_cpu : UInt32
    sq_thread_idle : UInt32
    features : UInt32
    wq_fd : UInt32
    resv : UInt32[3]
    sq_off : IoSqringOffsets
    cq_off : IoCqringOffsets
  end

  IORING_FEAT_SINGLE_MMAP     = 1_u32 << 0
  IORING_FEAT_NODROP          = 1_u32 << 1
  IORING_FEAT_SUBMIT_STABLE   = 1_u32 << 2
  IORING_FEAT_RW_CUR_POS      = 1_u32 << 3
  IORING_FEAT_CUR_PERSONALITY = 1_u32 << 4
  IORING_FEAT_FAST_POLL       = 1_u32 << 5
  IORING_FEAT_POLL_32BITS     = 1_u32 << 6
  IORING_FEAT_SQPOLL_NONFIXED = 1_u32 << 7
  IORING_FEAT_EXT_ARG         = 1_u32 << 8
  IORING_FEAT_NATIVE_WORKERS  = 1_u32 << 9
  IORING_FEAT_RSRC_TAGS       = 1_u32 << 10
  IORING_FEAT_CQE_SKIP        = 1_u32 << 11
  IORING_FEAT_LINKED_FILE     = 1_u32 << 12
  IORING_FEAT_REG_REG_RING    = 1_u32 << 13

  IORING_OP_NOP              =  0_u32
  IORING_OP_READV            =  1_u32
  IORING_OP_WRITEV           =  2_u32
  IORING_OP_FSYNC            =  3_u32
  IORING_OP_READ_FIXED       =  4_u32
  IORING_OP_WRITE_FIXED      =  5_u32
  IORING_OP_POLL_ADD         =  6_u32
  IORING_OP_POLL_REMOVE      =  7_u32
  IORING_OP_SYNC_FILE_RANGE  =  8_u32
  IORING_OP_SENDMSG          =  9_u32
  IORING_OP_RECVMSG          = 10_u32
  IORING_OP_TIMEOUT          = 11_u32
  IORING_OP_TIMEOUT_REMOVE   = 12_u32
  IORING_OP_ACCEPT           = 13_u32
  IORING_OP_ASYNC_CANCEL     = 14_u32
  IORING_OP_LINK_TIMEOUT     = 15_u32
  IORING_OP_CONNECT          = 16_u32
  IORING_OP_FALLOCATE        = 17_u32
  IORING_OP_OPENAT           = 18_u32
  IORING_OP_CLOSE            = 19_u32
  IORING_OP_FILES_UPDATE     = 20_u32
  IORING_OP_STATX            = 21_u32
  IORING_OP_READ             = 22_u32
  IORING_OP_WRITE            = 23_u32
  IORING_OP_FADVISE          = 24_u32
  IORING_OP_MADVISE          = 25_u32
  IORING_OP_SEND             = 26_u32
  IORING_OP_RECV             = 27_u32
  IORING_OP_OPENAT2          = 28_u32
  IORING_OP_EPOLL_CTL        = 29_u32
  IORING_OP_SPLICE           = 30_u32
  IORING_OP_PROVIDE_BUFFERS  = 31_u32
  IORING_OP_REMOVE_BUFFERS   = 32_u32
  IORING_OP_TEE              = 33_u32
  IORING_OP_SHUTDOWN         = 34_u32
  IORING_OP_RENAMEAT         = 35_u32
  IORING_OP_UNLINKAT         = 36_u32
  IORING_OP_MKDIRAT          = 37_u32
  IORING_OP_SYMLINKAT        = 38_u32
  IORING_OP_LINKAT           = 39_u32
  IORING_OP_MSG_RING         = 40_u32
  IORING_OP_FSETXATTR        = 41_u32
  IORING_OP_SETXATTR         = 42_u32
  IORING_OP_FGETXATTR        = 43_u32
  IORING_OP_GETXATTR         = 44_u32
  IORING_OP_SOCKET           = 45_u32
  IORING_OP_URING_CMD        = 46_u32
  IORING_OP_SEND_ZC          = 47_u32
  IORING_OP_SENDMSG_ZC       = 48_u32
  IORING_OP_READ_MULTISHOT   = 49_u32
  IORING_OP_WAITID           = 50_u32
  IORING_OP_FUTEX_WAIT       = 51_u32
  IORING_OP_FUTEX_WAKE       = 52_u32
  IORING_OP_FUTEX_WAITV      = 53_u32
  IORING_OP_FIXED_FD_INSTALL = 54_u32
  IORING_OP_FTRUNCATE        = 55_u32
  IORING_OP_BIND             = 56_u32
  IORING_OP_LISTEN           = 57_u32
  IORING_OP_LAST             = 58_u32

  IORING_OFF_SQ_RING =          0_u64
  IORING_OFF_CQ_RING =  0x8000000_u64
  IORING_OFF_SQES    = 0x10000000_u64
  # IORING_OFF_PBUF_RING = 0x80000000_u64
  # IORING_OFF_PBUF_SHIFT = 16
  # IORING_OFF_MMAP_MASK = 0xf8000000_u64

  IORING_REGISTER_BUFFERS             =  0_u32
  IORING_UNREGISTER_BUFFERS           =  1_u32
  IORING_REGISTER_FILES               =  2_u32
  IORING_UNREGISTER_FILES             =  3_u32
  IORING_REGISTER_EVENTFD             =  4_u32
  IORING_UNREGISTER_EVENTFD           =  5_u32
  IORING_REGISTER_FILES_UPDATE        =  6_u32
  IORING_REGISTER_EVENTFD_ASYNC       =  7_u32
  IORING_REGISTER_PROBE               =  8_u32
  IORING_REGISTER_PERSONALITY         =  9_u32
  IORING_UNREGISTER_PERSONALITY       = 10_u32
  IORING_REGISTER_RESTRICTIONS        = 11_u32
  IORING_REGISTER_ENABLE_RINGS        = 12_u32
  IORING_REGISTER_FILES2              = 13_u32
  IORING_REGISTER_FILES_UPDATE2       = 14_u32
  IORING_REGISTER_BUFFERS2            = 15_u32
  IORING_REGISTER_BUFFERS_UPDATE      = 16_u32
  IORING_REGISTER_IOWQ_AFF            = 17_u32
  IORING_UNREGISTER_IOWQ_AFF          = 18_u32
  IORING_REGISTER_IOWQ_MAX_WORKERS    = 19_u32
  IORING_REGISTER_RING_FDS            = 20_u32
  IORING_UNREGISTER_RING_FDS          = 21_u32
  IORING_REGISTER_PBUF_RING           = 22_u32
  IORING_UNREGISTER_PBUF_RING         = 23_u32
  IORING_REGISTER_SYNC_CANCEL         = 24_u32
  IORING_REGISTER_FILE_ALLOC_RANGE    = 25_u32
  IORING_REGISTER_PBUF_STATUS         = 26_u32
  IORING_REGISTER_NAPI                = 27_u32
  IORING_UNREGISTER_NAPI              = 28_u32
  IORING_REGISTER_LAST                = 29_u32
  IORING_REGISTER_USE_REGISTERED_RING = 1_u32 << 31

  IO_URING_OP_SUPPORTED = 1_u32

  struct IoUringProbeOp
    op : UInt8
    resv : UInt8
    flags : UInt16
    resv2 : UInt32
  end

  struct IoUringProbe
    last_op : UInt8
    ops_len : UInt8
    resv : UInt16
    resv2 : UInt32[3]
    ops : IoUringProbeOp[0]
  end
end
