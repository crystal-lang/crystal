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

  @@performance_frequency : Int64 = begin
    ret = LibC.QueryPerformanceFrequency(out frequency)
    if ret == 0
      raise RuntimeError.from_winerror("QueryPerformanceFrequency")
    end

    frequency
  end

  def self.monotonic : {Int64, Int32}
    if LibC.QueryPerformanceCounter(out ticks) == 0
      raise RuntimeError.from_winerror("QueryPerformanceCounter")
    end

    {ticks // @@performance_frequency, (ticks.remainder(@@performance_frequency) * NANOSECONDS_PER_SECOND / @@performance_frequency).to_i32}
  end

  def self.load_localtime : ::Time::Location?
    if LibC.GetTimeZoneInformation(out info) != LibC::TIME_ZONE_ID_INVALID
      initialize_location_from_TZI(info, "Local")
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
    return unless windows_name = iana_to_windows[iana_name]?

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
        initialize_location_from_TZI(tzi, iana_name)
      end
    end
  end

  private def self.initialize_location_from_TZI(info, name)
    stdname, dstname = normalize_zone_names(info)

    if info.standardDate.wMonth == 0_u16
      # No DST
      zone = ::Time::Location::Zone.new(stdname, info.bias * BIAS_TO_OFFSET_FACTOR, false)
      return ::Time::Location.new(name, [zone])
    end

    zones = [
      ::Time::Location::Zone.new(stdname, (info.bias + info.standardBias) * BIAS_TO_OFFSET_FACTOR, false),
      ::Time::Location::Zone.new(dstname, (info.bias + info.daylightBias) * BIAS_TO_OFFSET_FACTOR, true),
    ]

    first_date = info.standardDate
    second_date = info.daylightDate
    first_index = 0_u8
    second_index = 1_u8

    if info.standardDate.wMonth > info.daylightDate.wMonth
      first_date, second_date = second_date, first_date
      first_index, second_index = second_index, first_index
    end

    transitions = [] of ::Time::Location::ZoneTransition

    current_year = ::Time.utc.year

    (current_year - 100).upto(current_year + 100) do |year|
      tstamp = calculate_switchdate_in_year(year, first_date) - (zones[second_index].offset)
      transitions << ::Time::Location::ZoneTransition.new(tstamp, first_index, first_index == 0, false)

      tstamp = calculate_switchdate_in_year(year, second_date) - (zones[first_index].offset)
      transitions << ::Time::Location::ZoneTransition.new(tstamp, second_index, second_index == 0, false)
    end

    ::Time::Location.new(name, zones, transitions)
  end

  # Calculates the day of a DST switch in year *year* by extrapolating the date given in
  # *systemtime* (for the current year).
  #
  # Returns the number of seconds since UNIX epoch (Jan 1 1970) in the local time zone.
  private def self.calculate_switchdate_in_year(year, systemtime)
    # Windows specifies daylight savings information in "day in month" format:
    # wMonth is month number (1-12)
    # wDayOfWeek is appropriate weekday (Sunday=0 to Saturday=6)
    # wDay is week within the month (1 to 5, where 5 is last week of the month)
    # wHour, wMinute and wSecond are absolute time
    day = 1

    time = ::Time.utc(year, systemtime.wMonth.to_i32, day, systemtime.wHour.to_i32, systemtime.wMinute.to_i32, systemtime.wSecond.to_i32)
    i = systemtime.wDayOfWeek.to_i32 - (time.day_of_week.to_i32 % 7)

    if i < 0
      i += 7
    end

    day += i

    week = systemtime.wDay - 1

    if week < 4
      day += week * 7
    else
      # "Last" instance of the day.
      day += 4 * 7
      if day > ::Time.days_in_month(year, systemtime.wMonth)
        day -= 7
      end
    end

    time += (day - 1).days

    time.to_unix
  end

  # Normalizes the names of the standard and dst zones.
  private def self.normalize_zone_names(info : LibC::TIME_ZONE_INFORMATION) : Tuple(String, String)
    stdname, _ = String.from_utf16(info.standardName.to_slice.to_unsafe)

    if normalized_names = windows_zone_names[stdname]?
      return normalized_names
    end

    dstname, _ = String.from_utf16(info.daylightName.to_slice.to_unsafe)

    if english_name = translate_zone_name(stdname, dstname)
      if normalized_names = windows_zone_names[english_name]?
        return normalized_names
      end
    end

    # As a last resort, return the raw names as provided by TIME_ZONE_INFORMATION.
    # They are most probably localized and we couldn't find a translation.
    return stdname, dstname
  end

  REGISTRY_TIME_ZONES = %q(SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones).to_utf16
  Std                 = "Std".to_utf16
  Dlt                 = "Dlt".to_utf16
  TZI                 = "TZI".to_utf16

  # Searches the registry for an English name of a time zone named *stdname* or *dstname*
  # and returns the English name.
  private def self.translate_zone_name(stdname, dstname)
    WindowsRegistry.open?(LibC::HKEY_LOCAL_MACHINE, REGISTRY_TIME_ZONES) do |key_handle|
      WindowsRegistry.each_name(key_handle) do |name|
        WindowsRegistry.open?(key_handle, name) do |sub_handle|
          # TODO: Implement reading MUI
          std = WindowsRegistry.get_string(sub_handle, Std)
          dlt = WindowsRegistry.get_string(sub_handle, Dlt)

          if std == stdname || dlt == dstname
            return String.from_utf16(name)
          end
        end
      end
    end
  end
end
