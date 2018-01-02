require "c/win_nt"
require "c/int_safe"

lib LibC
  fun GetLastError : DWORD

  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32

  fun FormatMessageA(dwFlags : DWORD, lpSource : Void*, dwMessageId : DWORD, dwLanguageId : DWORD,
                     lpBuffer : LPSTR, nSize : DWORD, arguments : Void*) : DWORD
end
