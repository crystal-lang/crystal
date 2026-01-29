lib LibC
  IOSQE_IO_DRAIN = 1_u32 << 0
  IOSQE_IO_LINK  = 1_u32 << 2

  IORING_SETUP_SQPOLL       = 1_u32 << 1
  IORING_SETUP_CQSIZE       = 1_u32 << 3
  IORING_SETUP_ATTACH_WQ    = 1_u32 << 5
  IORING_SETUP_COOP_TASKRUN = 1_u32 << 8
  IORING_SETUP_NO_SQARRAY   = 1_u32 << 16

  IORING_SQ_NEED_WAKEUP = 1_u32 << 0

  IORING_ENTER_GETEVENTS = 1_u32 << 0
  IORING_ENTER_SQ_WAKEUP = 1_u32 << 1
  IORING_ENTER_SQ_WAIT   = 1_u32 << 2
  IORING_ENTER_EXT_ARG   = 1_u32 << 3

  IORING_ASYNC_CANCEL_ALL = 1_u32 << 0
  IORING_ASYNC_CANCEL_FD  = 1_u32 << 1

  IORING_FEAT_SINGLE_MMAP     = 1_u32 << 0
  IORING_FEAT_NODROP          = 1_u32 << 1
  IORING_FEAT_SUBMIT_STABLE   = 1_u32 << 2
  IORING_FEAT_RW_CUR_POS      = 1_u32 << 3
  IORING_FEAT_POLL_32BITS     = 1_u32 << 6
  IORING_FEAT_SQPOLL_NONFIXED = 1_u32 << 7
  IORING_FEAT_EXT_ARG         = 1_u32 << 8

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
  IORING_OP_RECV_ZC          = 59_u32
  IORING_OP_EPOLL_WAIT       = 60_u32
  IORING_OP_READV_FIXED      = 61_u32
  IORING_OP_WRITEV_FIXED     = 62_u32
  IORING_OP_PIPE             = 63_u32
  IORING_OP_LAST             = 64_u32

  IORING_OFF_SQ_RING =          0_u64
  IORING_OFF_CQ_RING =  0x8000000_u64
  IORING_OFF_SQES    = 0x10000000_u64

  IORING_REGISTER_PROBE         =  8_u32
  IORING_REGISTER_SYNC_CANCEL   = 24_u32
  IORING_REGISTER_SEND_MSG_RING = 31_u32
  IORING_REGISTER_LAST          = 35_u32

  IO_URING_OP_SUPPORTED = 1_u32

  union IoUringSqe__u1
    off : UInt64
    addr2 : UInt64
  end

  union IoUringSqe__u2
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
    pipe_flags : UInt32
  end

  struct IoUringSqe
    opcode : UInt8
    flags : UInt8
    ioprio : UInt16
    fd : Int32
    __u1 : IoUringSqe__u1
    addr : UInt64
    len : UInt32
    __u2 : IoUringSqe__u2
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

  struct IoUringGetEventsArg
    sigmask : UInt64
    sigmask_sz : UInt32
    pad : UInt32
    ts : UInt64
  end

  struct IoUringSyncCancelReg__kernel_timespec
    tv_sec : LongLong
    tv_nsec : LongLong
  end

  struct IoUringSyncCancelReg
    addr : UInt64
    fd : Int32
    flags : UInt32
    timeout : IoUringSyncCancelReg__kernel_timespec
    opcode : UInt8
    pad : UInt8[7]
    pad2 : UInt64[3]
  end

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
