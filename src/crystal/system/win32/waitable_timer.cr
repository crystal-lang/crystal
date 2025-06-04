require "c/ntdll"
require "c/synchapi"
require "c/winternl"

class Crystal::System::WaitableTimer
  getter handle : LibC::HANDLE

  def initialize
    flags = LibC::CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
    desired_access = LibC::SYNCHRONIZE | LibC::TIMER_QUERY_STATE | LibC::TIMER_MODIFY_STATE
    @handle = LibC.CreateWaitableTimerExW(nil, nil, flags, desired_access)
    raise RuntimeError.from_winerror("CreateWaitableTimerExW") if @handle.null?
  end

  def set(time : ::Time::Span) : Nil
    # convert absolute time to relative time, expressed in 100ns interval,
    # rounded up
    seconds, nanoseconds = System::Time.monotonic
    relative = time - ::Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
    ticks = (relative.to_i * 10_000_000 + (relative.nanoseconds + 99) // 100).clamp(0_i64..)

    # negative duration means relative time (positive would mean absolute
    # realtime clock)
    duration = -ticks

    ret = LibC.SetWaitableTimer(@handle, pointerof(duration), 0, nil, nil, 0)
    raise RuntimeError.from_winerror("SetWaitableTimer") if ret == 0
  end

  def cancel : Nil
    ret = LibC.CancelWaitableTimer(@handle)
    raise RuntimeError.from_winerror("CancelWaitableTimer") if ret == 0
  end

  def close : Nil
    LibC.CloseHandle(@handle)
  end
end
