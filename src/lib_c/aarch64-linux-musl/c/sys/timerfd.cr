require "../time"

lib LibC
  TFD_NONBLOCK      = 0o0004000
  TFD_CLOEXEC       = 0o2000000
  TFD_TIMER_ABSTIME = 1 << 0

  fun timerfd_create(ClockidT, Int) : Int
  fun timerfd_settime(Int, Int, Itimerspec*, Itimerspec*) : Int
end
