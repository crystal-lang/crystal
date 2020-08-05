require "c/basetsd"
require "c/int_safe"

lib LibC
  fun Sleep(dwMilliseconds : DWORD)
  fun WaitForSingleObject(hHandle : HANDLE, dwMilliseconds : DWORD) : DWORD
end
