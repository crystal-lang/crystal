require "c/ntdll"
require "c/synchapi"
require "c/winternl"

struct Crystal::System::WaitableTimer
  getter handle : LibC::HANDLE
  getter packet_handle : LibC::HANDLE

  def initialize
    flags = LibC::CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
    desired_access = LibC::SYNCHRONIZE | LibC::TIMER_QUERY_STATE | LibC::TIMER_MODIFY_STATE
    @handle = LibC.CreateWaitableTimerExW(nil, nil, flags, desired_access)
    raise RuntimeError.from_winerror("CreateWaitableTimerExW") if @handle.null?

    status = LibNTDLL.NtCreateWaitCompletionPacket(out @packet_handle, LibNTDLL::GENERIC_ALL, nil)
    raise RuntimeError.from_os_error("NtCreateWaitCompletionPacket", WinError.from_ntstatus(status)) unless status == 0
  end

  def set(time : ::Time::Span) : Nil
    seconds, nanoseconds = System::Time.monotonic
    now = ::Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)

    # negative duration means relative time (positive would mean absolute
    # realtime clock); in 100ns interval
    duration = -(((time - now).total_nanoseconds / 100).to_i64.clamp(0_i64..))

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
