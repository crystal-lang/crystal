require "c/int_safe"

lib LibC
  fun GetLastError : DWORD
  fun SetLastError(dwErrCode : DWORD)
end
