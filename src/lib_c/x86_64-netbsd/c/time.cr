require "./sys/types"

lib LibC
  CLOCK_REALTIME  = 0
  CLOCK_MONOTONIC = 3

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

  fun clock_gettime = __clock_gettime50(x0 : ClockidT, x1 : Timespec*) : Int
  fun clock_settime = __clock_settime50(x0 : ClockidT, x1 : Timespec*) : Int
  fun gmtime_r = __gmtime_r50(x0 : TimeT*, x1 : Tm*) : Tm*
  fun localtime_r = __localtime_r50(x0 : TimeT*, x1 : Tm*) : Tm*
  fun mktime = __mktime50(x0 : Tm*) : TimeT
  fun tzset : Void
  fun timegm = __timegm50(x0 : Tm*) : TimeT

  $daylight : Int
  $timezone : Long
  $tzname : StaticArray(Char*, 2)
end
