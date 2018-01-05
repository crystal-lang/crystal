require "./sys/types"

lib LibC
  CLOCK_REALTIME            = 0
  CLOCK_PROCESS_CPUTIME_ID  = 2
  CLOCK_MONOTONIC           = 3
  CLOCK_THREAD_CPUTIME_ID   = 4
  CLOCK_UPTIME              = 5
  CLOCK_BOOTTIME            = 6

  struct Tm
    tm_sec : Int       # seconds after the minute [0-60]
    tm_min : Int       # minutes after the hour [0-59]
    tm_hour : Int      # hours since midnight [0-23]
    tm_mday : Int      # day of the month [1-31]
    tm_mon : Int       # months since January [0-11]
    tm_year : Int      # years since 1900
    tm_wday : Int      # days since Sunday [0-6]
    tm_yday : Int      # days since January 1 [0-365]
    tm_isdst : Int     # Daylight Saving Time flag
    tm_gmtoff : Long   # offset from UTC in seconds
    tm_zone : Char*    # timezone abbreviation
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

  $daylight : Int
  $timezone : Long
  $tzname : StaticArray(Char*, 2)
end
