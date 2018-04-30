require "c/winnt"
require "c/win_def"
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
end
