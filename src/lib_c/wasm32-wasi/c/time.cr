require "./sys/types"

lib LibC
  {% if flag?(:wasip1) %}
    CLOCK_MONOTONIC = 1
    CLOCK_REALTIME  = 0
  {% else %}
    $_CLOCK_MONOTONIC : UInt8
    $_CLOCK_REALTIME : UInt8
    CLOCK_MONOTONIC = pointerof(LibC._CLOCK_MONOTONIC).as(ClockidT)
    CLOCK_REALTIME  = pointerof(LibC._CLOCK_REALTIME).as(ClockidT)
  {% end %}

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
    tm_gmtoff : Int
    tm_zone : Char*
    __tm_nsec : Int
  end

  struct Timespec
    tv_sec : TimeT
    tv_nsec : Long
  end

  fun clock_gettime(x0 : ClockidT, x1 : Timespec*) : Int
  fun gmtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun localtime_r(x0 : TimeT*, x1 : Tm*) : Tm*
  fun mktime(x0 : Tm*) : TimeT
  fun nanosleep(x0 : Timespec*, x1 : Timespec*) : Int
  fun timegm(x0 : Tm*) : TimeT
end
