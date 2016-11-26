
lib LibC
  CLOCK_MONOTONIC = 1
  CLOCK_REALTIME  = 0

  alias SusecondsT = Long
  alias TimeT = Long

  struct Timeval
    tv_sec : TimeT
    tv_usec : SusecondsT
  end

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

  fun gmtime_r(timer : TimeT*, tp : Tm*) : Tm*
  fun localtime_r(timer : TimeT*, tp : Tm*) : Tm*
  fun mktime(tp : Tm*) : TimeT
  fun tzset : Void
  fun timegm(tp : Tm*) : TimeT

  $daylight : Int
  $timezone : Long
  $tzname : StaticArray(Char*, 2)
end
