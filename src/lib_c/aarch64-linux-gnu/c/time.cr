require "./sys/types"

lib LibC
  CLOCK_MONOTONIC = 1
  CLOCK_REALTIME  = 0

  struct Timespec
    tv_sec : TimeT
    tv_nsec : Long
  end

  fun clock_gettime(clock_id : ClockidT, tp : Timespec*) : Int
end
