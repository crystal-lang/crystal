require "c/winnt"

lib LibC
  fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL
end
