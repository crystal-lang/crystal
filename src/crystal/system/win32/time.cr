require "c/winbase"
require "c/timezoneapi"
require "c/windows"
require "./zone_names"
require "./windows_registry"

module Crystal::System::Time
  # Win32 epoch is 1601-01-01 00:00:00 UTC
  WINDOWS_EPOCH_IN_SECONDS = 50_491_123_200_i64

  # Resolution of FILETIME is 100 nanoseconds
  NANOSECONDS_PER_FILETIME_TICK = 100

  NANOSECONDS_PER_SECOND    = 1_000_000_000
  FILETIME_TICKS_PER_SECOND = NANOSECONDS_PER_SECOND // NANOSECONDS_PER_FILETIME_TICK

  BIAS_TO_OFFSET_FACTOR = -60

  def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
    {% if LibC.has_method?("GetSystemTimePreciseAsFileTime") %}
      LibC.GetSystemTimePreciseAsFileTime(out filetime)
      filetime_to_seconds_and_nanoseconds(filetime)
    {% else %}
      LibC.GetSystemTimeAsFileTime(out filetime)
      filetime_to_seconds_and_nanoseconds(filetime)
    {% end %}
  end

  def self.filetime_to_seconds_and_nanoseconds(filetime) : {Int64, Int32}
    since_epoch = (filetime.dwHighDateTime.to_u64 << 32) | filetime.dwLowDateTime.to_u64

    seconds = (since_epoch / FILETIME_TICKS_PER_SECOND).to_i64 + WINDOWS_EPOCH_IN_SECONDS
    nanoseconds = since_epoch.remainder(FILETIME_TICKS_PER_SECOND).to_i32 * NANOSECONDS_PER_FILETIME_TICK

    {seconds, nanoseconds}
  end

  def self.from_filetime(filetime) : ::Time
    seconds, nanoseconds = filetime_to_seconds_and_nanoseconds(filetime)
    ::Time.utc(seconds: seconds, nanoseconds: nanoseconds)
  end

  def self.to_filetime(time : ::Time) : LibC::FILETIME
    span = time - ::Time.utc(seconds: WINDOWS_EPOCH_IN_SECONDS, nanoseconds: 0)
    ticks = span.to_i.to_u64 * FILETIME_TICKS_PER_SECOND + span.nanoseconds // NANOSECONDS_PER_FILETIME_TICK
    filetime = uninitialized LibC::FILETIME
    filetime.dwHighDateTime = (ticks >> 32).to_u32
    filetime.dwLowDateTime = ticks.to_u32!
    filetime
  end

  def self.filetime_to_f64secs(filetime) : Float64
    ((filetime.dwHighDateTime.to_u64 << 32) | filetime.dwLowDateTime.to_u64).to_f64 / FILETIME_TICKS_PER_SECOND.to_f64
  end

  private class_getter performance_frequency : Int64 do
    LibC.QueryPerformanceFrequency(out frequency)
    frequency
  end

  def self.monotonic : {Int64, Int32}
    LibC.QueryPerformanceCounter(out ticks)
    frequency = performance_frequency
    {ticks // frequency, (ticks.remainder(frequency) * NANOSECONDS_PER_SECOND / frequency).to_i32}
  end

  def self.ticks : UInt64
    LibC.QueryPerformanceCounter(out ticks)
    ticks.to_u64! &* (NANOSECONDS_PER_SECOND // performance_frequency)
  end

  def self.load_localtime : ::Time::Location?
    if LibC.GetDynamicTimeZoneInformation(out info) != LibC::TIME_ZONE_ID_INVALID
      windows_name = String.from_utf16(info.timeZoneKeyName.to_slice, truncate_at_null: true)

      return unless canonical_iana_name = windows_to_iana[windows_name]?
      return unless windows_info = iana_to_windows[canonical_iana_name]?
      _, stdname, dstname = windows_info

      initialize_location_from_TZI(pointerof(info).as(LibC::TIME_ZONE_INFORMATION*).value, canonical_iana_name, windows_name, stdname, dstname)
    end
  end

  def self.zone_sources : Enumerable(String)
    [] of String
  end

  # https://learn.microsoft.com/en-us/windows/win32/api/timezoneapi/ns-timezoneapi-time_zone_information#remarks
  @[Extern]
  private record REG_TZI_FORMAT,
    bias : LibC::LONG,
    standardBias : LibC::LONG,
    daylightBias : LibC::LONG,
    standardDate : LibC::SYSTEMTIME,
    daylightDate : LibC::SYSTEMTIME

  def self.load_iana_zone(iana_name : String) : ::Time::Location?
    return unless windows_info = iana_to_windows[iana_name]?
    windows_name, stdname, dstname = windows_info

    WindowsRegistry.open?(LibC::HKEY_LOCAL_MACHINE, REGISTRY_TIME_ZONES) do |key_handle|
      WindowsRegistry.open?(key_handle, windows_name.to_utf16) do |sub_handle|
        reg_tzi = uninitialized REG_TZI_FORMAT
        WindowsRegistry.get_raw(sub_handle, TZI, Slice.new(pointerof(reg_tzi), 1).to_unsafe_bytes)

        tzi = LibC::TIME_ZONE_INFORMATION.new(
          bias: reg_tzi.bias,
          standardDate: reg_tzi.standardDate,
          standardBias: reg_tzi.standardBias,
          daylightDate: reg_tzi.daylightDate,
          daylightBias: reg_tzi.daylightBias,
        )
        WindowsRegistry.get_raw(sub_handle, Std, tzi.standardName.to_slice.to_unsafe_bytes)
        WindowsRegistry.get_raw(sub_handle, Dlt, tzi.daylightName.to_slice.to_unsafe_bytes)
        initialize_location_from_TZI(tzi, iana_name, windows_name, stdname, dstname)
      end
    end
  end

  private def self.initialize_location_from_TZI(info, name, windows_name, stdname, dstname)
    if info.standardDate.wMonth == 0_u16 || info.daylightDate.wMonth == 0_u16
      # No DST
      zone = ::Time::Location::Zone.new(stdname, info.bias * BIAS_TO_OFFSET_FACTOR, false)
      default_tz_args = {0, 0, ::Time::TZ::MonthWeekDay.default, ::Time::TZ::MonthWeekDay.default}
      return ::Time::WindowsLocation.new(name, [zone], windows_name, default_tz_args)
    end

    zones = [
      ::Time::Location::Zone.new(stdname, (info.bias + info.standardBias) * BIAS_TO_OFFSET_FACTOR, false),
      ::Time::Location::Zone.new(dstname, (info.bias + info.daylightBias) * BIAS_TO_OFFSET_FACTOR, true),
    ]

    std_index = 0
    dst_index = 1
    transition1 = systemtime_to_mwd(info.daylightDate)
    transition2 = systemtime_to_mwd(info.standardDate)
    tz_args = {std_index, dst_index, transition1, transition2}

    ::Time::WindowsLocation.new(name, zones, windows_name, tz_args)
  end

  private def self.systemtime_to_mwd(time)
    seconds = 3600 * time.wHour + 60 * time.wMinute + time.wSecond
    ::Time::TZ::MonthWeekDay.new(time.wMonth.to_i8, time.wDay.to_i8, time.wDayOfWeek.to_i8, seconds)
  end

  REGISTRY_TIME_ZONES = System.wstr_literal %q(SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones)
  Std                 = System.wstr_literal "Std"
  Dlt                 = System.wstr_literal "Dlt"
  TZI                 = System.wstr_literal "TZI"
end
