require "c/int_safe"

lib LibC
  EXCEPTION_CONTINUE_SEARCH = LONG.new!(0)

  EXCEPTION_ACCESS_VIOLATION = 0xC0000005_u32
  EXCEPTION_STACK_OVERFLOW   = 0xC00000FD_u32

  alias PVECTORED_EXCEPTION_HANDLER = EXCEPTION_POINTERS* -> LONG

  fun GetLastError : DWORD
  fun SetLastError(dwErrCode : DWORD)
  fun AddVectoredExceptionHandler(first : DWORD, handler : PVECTORED_EXCEPTION_HANDLER) : Void*
end
