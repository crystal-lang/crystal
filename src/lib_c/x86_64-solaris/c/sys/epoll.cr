lib LibC
  EPOLLIN    =  0x001_u32
  EPOLLOUT   =  0x004_u32
  EPOLLERR   =  0x008_u32
  EPOLLHUP   =  0x010_u32
  EPOLLRDHUP = 0x2000_u32

  EPOLLEXCLUSIVE = 1_u32 << 28
  EPOLLET        = 1_u32 << 31

  EPOLL_CTL_ADD = 1
  EPOLL_CTL_DEL = 2
  EPOLL_CTL_MOD = 3

  EPOLL_CLOEXEC = 0o2000000

  union EpollDataT
    ptr : Void*
    fd : Int
    u32 : UInt32
    u64 : UInt64
  end

  @[Packed]
  struct EpollEvent
    events : UInt32
    data : EpollDataT
  end

  fun epoll_create1(Int) : Int
  fun epoll_ctl(Int, Int, Int, EpollEvent*) : Int
  fun epoll_wait(Int, EpollEvent*, Int, Int) : Int
end
