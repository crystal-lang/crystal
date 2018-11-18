require "c/int_safe"

lib LibC
  fun Sleep(dwMilliseconds : DWORD)
end
