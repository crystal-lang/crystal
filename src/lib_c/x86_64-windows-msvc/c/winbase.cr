require "c/win_def"
require "c/winnt"

@[Link("UserEnv")]
lib LibC
  fun GetLastError : DWORD
  fun SetLastError(dwErrCode : DWORD)

  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32

  fun FormatMessageW(dwFlags : DWORD, lpSource : Void*, dwMessageId : DWORD, dwLanguageId : DWORD,
                     lpBuffer : LPWSTR, nSize : DWORD, arguments : Void*) : DWORD

  struct FILETIME
    dwLowDateTime : DWORD
    dwHighDateTime : DWORD
  end

  struct SYSTEMTIME
    wYear : WORD
    wMonth : WORD
    wDayOfWeek : WORD
    wDay : WORD
    wHour : WORD
    wMinute : WORD
    wSecond : WORD
    wMilliseconds : WORD
  end

  struct TIME_ZONE_INFORMATION
    bias : LONG
    standardName : StaticArray(WCHAR, 32)
    standardDate : SYSTEMTIME
    standardBias : LONG
    daylightName : StaticArray(WCHAR, 32)
    daylightDate : SYSTEMTIME
    daylightBias : LONG
  end

  TIME_ZONE_ID_UNKNOWN  = 0_u32
  TIME_ZONE_ID_STANDARD = 1_u32
  TIME_ZONE_ID_DAYLIGHT = 2_u32

  fun GetTimeZoneInformation(tz_info : TIME_ZONE_INFORMATION*) : DWORD
  fun GetSystemTimeAsFileTime(time : FILETIME*)
  fun GetSystemTimePreciseAsFileTime(time : FILETIME*)

  fun QueryPerformanceCounter(performance_count : Int64*) : BOOL
  fun QueryPerformanceFrequency(frequency : Int64*) : BOOL

  fun GetCurrentDirectoryW(nBufferLength : DWORD, lpBuffer : LPWSTR) : DWORD
  fun SetCurrentDirectoryW(lpPathname : LPWSTR) : BOOL

  SYMBOLIC_LINK_FLAG_DIRECTORY                 = 0x1
  SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE = 0x2

  fun CreateHardLinkW(lpFileName : LPWSTR, lpExistingFileName : LPWSTR, lpSecurityAttributes : Void*) : BOOL
  fun CreateSymbolicLinkW(lpSymlinkFileName : LPWSTR, lpTargetFileName : LPWSTR, dwFlags : DWORD) : BOOLEAN

  struct WIN32_FILE_ATTRIBUTE_DATA
    dwFileAttributes : DWORD
    ftCreationTime : FILETIME
    ftLastAccessTime : FILETIME
    ftLastWriteTime : FILETIME
    nFileSizeHigh : DWORD
    nFileSizeLow : DWORD
  end

  enum GET_FILEEX_INFO_LEVELS
    GetFileExInfoStandard
    GetFileExMaxInfoLevel
  end

  struct SECURITY_ATTRIBUTES
    nLength : DWORD
    lpSecurityDescriptor : Void*
    bInheritHandle : BOOL
  end

  INVALID_HANDLE_VALUE = HANDLE.new(-1)

  fun CloseHandle(hObject : HANDLE) : BOOL

  fun GetEnvironmentVariableW(lpName : LPWSTR, lpBuffer : LPWSTR, nSize : DWORD) : DWORD
  fun GetEnvironmentStringsW : LPWCH
  fun CreateEnvironmentBlock(lpEnvironment : LPVOID*, hToken : HANDLE, bInherit : BOOL) : BOOL
  fun DestroyEnvironmentBlock(lpEnvironment : LPVOID) : BOOL
  fun FreeEnvironmentStringsW(lpszEnvironmentBlock : LPWCH) : BOOL
  fun SetEnvironmentVariableW(lpName : LPWSTR, lpValue : LPWSTR) : BOOL
end
