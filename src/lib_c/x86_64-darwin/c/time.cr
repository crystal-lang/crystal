require "./sys/types"

lib LibC
  CLOCK_REALTIME      = 0
  CLOCK_MONOTONIC     = 6
  CLOCK_MONOTONIC_RAW = 4
  CLOCK_UPTIME_RAW    = 8

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

  fun clock_gettime(__clock_id : ClockidT, __tp : Timespec*) : Int
  fun gmtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun localtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun mktime(x0 : Tm*) : TimeT
  fun nanosleep(x0 : Timespec*, x1 : Timespec*) : Int
  fun tzset : Void
  fun timegm(x0 : Tm*) : TimeT

  $daylight : Int
  $timezone : Long
  $tzname : Char**
end
