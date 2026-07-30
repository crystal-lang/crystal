{% skip_file unless flag?(:linux) %}
require "c/sys/timerfd"

struct Crystal::System::TimerFD
  getter fd : Int32

  # Create a `timerfd` instance set to the monotonic clock.
  def initialize
    # We must use the same clock as in `Crystal::System::Time.clock_gettime` in
    # order to accept absolute timers with `Time::Instant` values.
    # Since `TimerFD` is only used on Linux, we do not have to differentiate
    # between different targets.
    @fd = LibC.timerfd_create(LibC::CLOCK_BOOTTIME, LibC::TFD_CLOEXEC)
    raise RuntimeError.from_errno("timerfd_settime") if @fd == -1
  end

  # Arm (start) the timer to run at *time* (absolute time).
  def set(time : ::Time::Instant) : Nil
    itimerspec = uninitialized LibC::Itimerspec
    itimerspec.it_interval.tv_sec = 0
    itimerspec.it_interval.tv_nsec = 0
    itimerspec.it_value.tv_sec = typeof(itimerspec.it_value.tv_sec).new!(time.@seconds)
    itimerspec.it_value.tv_nsec = typeof(itimerspec.it_value.tv_nsec).new!(time.@nanoseconds)
    ret = LibC.timerfd_settime(@fd, LibC::TFD_TIMER_ABSTIME, pointerof(itimerspec), nil)
    raise RuntimeError.from_errno("timerfd_settime") if ret == -1
  end

  # Disarm (stop) the timer.
  def cancel : Nil
    itimerspec = LibC::Itimerspec.new
    ret = LibC.timerfd_settime(@fd, LibC::TFD_TIMER_ABSTIME, pointerof(itimerspec), nil)
    raise RuntimeError.from_errno("timerfd_settime") if ret == -1
  end

  def close
    LibC.close(@fd)
  end
end
