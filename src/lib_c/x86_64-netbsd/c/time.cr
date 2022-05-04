require "./sys/types"

lib LibC
  CLOCK_REALTIME  = 0
  CLOCK_MONOTONIC = 3

  struct Timespec
    tv_sec : TimeT
    tv_nsec : Long
  end

  fun clock_gettime = __clock_gettime50(x0 : ClockidT, x1 : Timespec*) : Int
end
