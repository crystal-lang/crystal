require "c/winnt"
require "c/winbase"

lib LibC
  struct TIME_ZONE_INFORMATION
    bias : LONG
    standardName : StaticArray(WCHAR, 32)
    standardDate : SYSTEMTIME
    standardBias : LONG
    daylightName : StaticArray(WCHAR, 32)
    daylightDate : SYSTEMTIME
    daylightBias : LONG
  end

  TIME_TONE_ID_INVALID  = 0xffffffff_u32
  TIME_ZONE_ID_UNKNOWN  =          0_u32
  TIME_ZONE_ID_STANDARD =          1_u32
  TIME_ZONE_ID_DAYLIGHT =          2_u32

  fun GetTimeZoneInformation(tz_info : TIME_ZONE_INFORMATION*) : DWORD
end
