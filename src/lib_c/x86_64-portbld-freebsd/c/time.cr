require "./sys/types"

lib LibC
  CLOCK_MONOTONIC = 4
  CLOCK_REALTIME  = 0

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
  fun tzset : Void
  fun timegm(x0 : Tm*) : TimeT

  fun timezone(x0 : Int, x1 : Int) : Char*
  $tzname : Char**
end
