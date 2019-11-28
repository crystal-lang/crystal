require "c/basetsd"

lib LibC
  INFINITE = -1
  fun Sleep(dwMilliseconds : DWORD)
  fun WaitForSingleObject(
    hHandle : HANDLE,
    dwMilliseconds : DWORD
  ) : DWORD

  alias WAITORTIMERCALLBACK = (Void*, Bool -> Nil)
  WT_EXECUTEONLYONCE = 0x00000008
  fun RegisterWaitForSingleObject(
    phNewWaitObject : HANDLE*,
    hObject : HANDLE,
    callback : WAITORTIMERCALLBACK,
    context : Void*,
    dwMilliseconds : ULong,
    dwFlags : ULong
  ) : BOOL

  fun UnregisterWait(waitHandle : HANDLE) : BOOL
end
