require "../time"

lib LibC
  EVFILT_READ  = -1_i16
  EVFILT_WRITE = -2_i16

  EV_ADD     = 0x0001_u16
  EV_DELETE  = 0x0002_u16
  EV_ONESHOT = 0x0010_u16
  EV_EOF     = 0x8000_u16
  EV_ERROR   = 0x4000_u16

  struct Kevent
    ident : SizeT # UintptrT
    filter : Short
    flags : UShort
    fflags : UInt
    data : Int64
    udata : Void*
  end

  fun kqueue1(flags : Int) : Int
  fun kevent(kq : Int, changelist : Kevent*, nchanges : Int, eventlist : Kevent*, nevents : Int, timeout : Timespec*) : Int
end
