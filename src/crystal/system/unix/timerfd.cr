require "c/sys/timerfd"

struct Crystal::System::TimerFD
  getter fd : Int32

  # Create a `timerfd` instance set to the monotonic clock.
  def initialize
    @fd = LibC.timerfd_create(LibC::CLOCK_MONOTONIC, LibC::TFD_CLOEXEC)
    raise RuntimeError.from_errno("timerfd_settime") if @fd == -1
  end

  # Arm (start) the timer to run at *time* (absolute time).
  def set(time : ::Time::Span) : Nil
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
