require "c/winnt"

lib LibC
  ENABLE_PROCESSED_INPUT        = 0x0001
  ENABLE_LINE_INPUT             = 0x0002
  ENABLE_ECHO_INPUT             = 0x0004
  ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200

  ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

  fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL
  fun SetConsoleMode(hConsoleHandle : HANDLE, dwMode : DWORD) : BOOL

  fun GetConsoleCP : DWORD
  fun GetConsoleOutputCP : DWORD
end
