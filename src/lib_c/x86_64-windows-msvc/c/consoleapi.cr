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

  fun ReadConsoleW(
    hConsoleInput : HANDLE,
    lpBuffer : Void*,
    nNumberOfCharsToRead : DWORD,
    lpNumberOfCharsRead : DWORD*,
    pInputControl : Void*,
  ) : BOOL

  CTRL_C_EVENT        = 0
  CTRL_BREAK_EVENT    = 1
  CTRL_CLOSE_EVENT    = 2
  CTRL_LOGOFF_EVENT   = 5
  CTRL_SHUTDOWN_EVENT = 6

  alias PHANDLER_ROUTINE = DWORD -> BOOL

  fun SetConsoleCtrlHandler(handlerRoutine : PHANDLER_ROUTINE, add : BOOL) : BOOL
end
