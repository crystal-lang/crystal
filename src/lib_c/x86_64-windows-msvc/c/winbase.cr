require "c/winnt"
require "c/win_def"
require "c/int_safe"
require "c/minwinbase"

lib LibC
  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32
  FORMAT_MESSAGE_MAX_WIDTH_MASK  = 0x000000FF_u32

  fun FormatMessageW(dwFlags : DWORD, lpSource : Void*, dwMessageId : DWORD, dwLanguageId : DWORD,
                     lpBuffer : LPWSTR, nSize : DWORD, arguments : Void*) : DWORD

  fun GetSystemTimeAsFileTime(time : FILETIME*)
  fun GetSystemTimePreciseAsFileTime(time : FILETIME*)

  SYMBOLIC_LINK_FLAG_DIRECTORY                 = 0x1
  SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE = 0x2

  fun CreateHardLinkW(lpFileName : LPWSTR, lpExistingFileName : LPWSTR, lpSecurityAttributes : Void*) : BOOL
  fun CreateSymbolicLinkW(lpSymlinkFileName : LPWSTR, lpTargetFileName : LPWSTR, dwFlags : DWORD) : BOOLEAN

  fun GetEnvironmentVariableW(lpName : LPWSTR, lpBuffer : LPWSTR, nSize : DWORD) : DWORD
  fun GetEnvironmentStringsW : LPWCH
  fun FreeEnvironmentStringsW(lpszEnvironmentBlock : LPWCH) : BOOL
  fun SetEnvironmentVariableW(lpName : LPWSTR, lpValue : LPWSTR) : BOOL

  INFINITE = 0xFFFFFFFF

  STARTF_USESTDHANDLES = 0x00000100

  MOVEFILE_REPLACE_EXISTING      =  0x1_u32
  MOVEFILE_COPY_ALLOWED          =  0x2_u32
  MOVEFILE_DELAY_UNTIL_REBOOT    =  0x4_u32
  MOVEFILE_WRITE_THROUGH         =  0x8_u32
  MOVEFILE_CREATE_HARDLINK       = 0x10_u32
  MOVEFILE_FAIL_IF_NOT_TRACKABLE = 0x20_u32

  fun MoveFileExW(lpExistingFileName : LPWSTR, lpNewFileName : LPWSTR, dwFlags : DWORD) : BOOL
end
