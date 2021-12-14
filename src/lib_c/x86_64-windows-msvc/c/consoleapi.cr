require "c/winnt"

lib LibC
  fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL

  fun GetConsoleCP : DWORD
  fun GetConsoleOutputCP : DWORD
end
