require "./sys/types"

lib LibC
  CLOCK_REALTIME           =  0
  CLOCK_MONOTONIC          =  1
  CLOCK_PROCESS_CPUTIME_ID =  2
  CLOCK_THREAD_CPUTIME_ID  =  3
  CLOCK_MONOTONIC_RAW      =  4
  CLOCK_REALTIME_COARSE    =  5
  CLOCK_MONOTONIC_COARSE   =  6
  CLOCK_BOOTTIME           =  7
  CLOCK_REALTIME_ALARM     =  8
  CLOCK_BOOTTIME_ALARM     =  9
  CLOCK_SGI_CYCLE          = 10
  CLOCK_TAI                = 11

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

  struct Itimerspec
    it_interval : Timespec
    it_value : Timespec
  end

  fun clock_gettime(__clock : ClockidT, __ts : Timespec*) : Int
  fun clock_settime(__clock : ClockidT, __ts : Timespec*) : Int
  fun gmtime_r(__t : TimeT*, __tm : Tm*) : Tm*
  fun localtime_r(__t : TimeT*, __tm : Tm*) : Tm*
  fun mktime(__tm : Tm*) : TimeT
  fun nanosleep(__req : Timespec*, __rem : Timespec*) : Int
  fun tzset : Void
  fun timegm(__tm : Tm*) : TimeT

  $daylight : Int
  $timezone : Long
  $tzname : StaticArray(Char*, 2)
end
