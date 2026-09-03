require "c/int_safe"
require "c/ntstatus"

lib LibC
  EXCEPTION_CONTINUE_SEARCH = LONG.new!(0)

  EXCEPTION_ACCESS_VIOLATION = LibC::STATUS_ACCESS_VIOLATION
  EXCEPTION_STACK_OVERFLOW   = LibC::STATUS_STACK_OVERFLOW

  alias PVECTORED_EXCEPTION_HANDLER = EXCEPTION_POINTERS* -> LONG

  fun GetLastError : DWORD
  fun SetLastError(dwErrCode : DWORD)
  fun AddVectoredExceptionHandler(first : DWORD, handler : PVECTORED_EXCEPTION_HANDLER) : Void*
end
