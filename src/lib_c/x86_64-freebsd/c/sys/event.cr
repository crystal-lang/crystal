require "../time"

lib LibC
  EVFILT_READ  =  -1_i16
  EVFILT_WRITE =  -2_i16
  EVFILT_TIMER =  -7_i16
  EVFILT_USER  = -11_i16

  EV_ADD     = 0x0001_u16
  EV_DELETE  = 0x0002_u16
  EV_ENABLE  = 0x0004_u16
  EV_ONESHOT = 0x0010_u16
  EV_CLEAR   = 0x0020_u16
  EV_EOF     = 0x8000_u16
  EV_ERROR   = 0x4000_u16

  NOTE_NSECONDS = 0x00000008_u32
  NOTE_TRIGGER  = 0x01000000_u32

  struct Kevent
    ident : SizeT # UintptrT
    filter : Short
    flags : UShort
    fflags : UInt
    data : Int64
    udata : Void*
    ext : UInt64[4]
  end

  fun kqueue1(flags : Int) : Int
  fun kevent(kq : Int, changelist : Kevent*, nchanges : Int, eventlist : Kevent*, nevents : Int, timeout : Timespec*) : Int
end
