require "c/winnt"

lib LibC
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

  fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL
  fun SetConsoleMode(hConsoleHandle : HANDLE, dwMode : DWORD) : BOOL

  fun GetConsoleCP : DWORD
  fun GetConsoleOutputCP : DWORD
end
