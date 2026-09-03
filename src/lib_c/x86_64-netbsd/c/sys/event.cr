require "../time"

lib LibC
  EVFILT_READ  = 0_u32
  EVFILT_WRITE = 1_u32
  EVFILT_TIMER = 6_u32
  EVFILT_USER  = 8_u32

  EV_ADD     = 0x0001_u32
  EV_DELETE  = 0x0002_u32
  EV_ENABLE  = 0x0004_u16
  EV_ONESHOT = 0x0010_u32
  EV_CLEAR   = 0x0020_u32
  EV_EOF     = 0x8000_u32
  EV_ERROR   = 0x4000_u32

  NOTE_NSECONDS = 0x00000003_u32
  NOTE_TRIGGER  = 0x01000000_u32

  struct Kevent
    ident : SizeT # UintptrT
    filter : UInt32
    flags : UInt32
    fflags : UInt32
    data : Int64
    udata : Void*
    ext : UInt64[4]
  end

  fun kqueue1(flags : Int) : Int
  fun kevent = __kevent50(kq : Int, changelist : Kevent*, nchanges : SizeT, eventlist : Kevent*, nevents : SizeT, timeout : Timespec*) : Int
end
