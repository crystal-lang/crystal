require "./sys/types"

lib LibC
  CLOCK_REALTIME           =  0
  CLOCK_MONOTONIC          =  4
  CLOCK_UPTIME             =  5
  CLOCK_UPTIME_PRECISE     =  7
  CLOCK_UPTIME_FAST        =  8
  CLOCK_REALTIME_PRECISE   =  9
  CLOCK_REALTIME_FAST      = 10
  CLOCK_MONOTONIC_PRECISE  = 11
  CLOCK_MONOTONIC_FAST     = 12
  CLOCK_SECOND             = 13
  CLOCK_THREAD_CPUTIME_ID  = 14
  CLOCK_PROCESS_CPUTIME_ID = 15

  struct Tm
    tm_sec : Int
    tm_min : Int
    tm_hour : Int
    tm_mday : Int
    tm_mon : Int
    tm_year : Int
    tm_wday : Int
    tm_yday : Int
    tm_isdst : Int
    tm_gmtoff : Long
    tm_zone : Char*
  end

  struct Timespec
    tv_sec : TimeT
    tv_nsec : Long
  end

  fun clock_gettime(x0 : ClockidT, x1 : Timespec*) : Int
  fun clock_settime(x0 : ClockidT, x1 : Timespec*) : Int
  fun gmtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun localtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun mktime(x0 : Tm*) : TimeT
  fun nanosleep(x0 : Timespec*, x1 : Timespec*) : Int
  fun tzset : Void
  fun timegm(x0 : Tm*) : TimeT

  fun timezone(x0 : Int, x1 : Int) : Char*
  $tzname : Char**
end
