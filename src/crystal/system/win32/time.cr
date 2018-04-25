require "c/winbase"
require "winerror"
require "./zone_names"

module Crystal::System::Time
  # Win32 epoch is 1601-01-01 00:00:00 UTC
  WINDOWS_EPOCH_IN_SECONDS = 50_491_123_200_i64

  # Resolution of FILETIME is 100 nanoseconds
  NANOSECONDS_PER_FILETIME_TICK = 100

  NANOSECONDS_PER_SECOND    = 1_000_000_000
  FILETIME_TICKS_PER_SECOND = NANOSECONDS_PER_SECOND / NANOSECONDS_PER_FILETIME_TICK

  BIAS_TO_OFFSET_FACTOR = -60

  def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
    # TODO: Needs a check if `GetSystemTimePreciseAsFileTime` is actually available (only >= Windows 8)
    # and use `GetSystemTimeAsFileTime` as fallback.
    LibC.GetSystemTimePreciseAsFileTime(out filetime)
    since_epoch = (filetime.dwHighDateTime.to_u64 << 32) | filetime.dwLowDateTime.to_u64

    seconds = (since_epoch / FILETIME_TICKS_PER_SECOND).to_i64 + WINDOWS_EPOCH_IN_SECONDS
    nanoseconds = since_epoch.remainder(FILETIME_TICKS_PER_SECOND).to_i32 * NANOSECONDS_PER_FILETIME_TICK

    {seconds, nanoseconds}
  end

  @@performance_frequency : Int64 = begin
    ret = LibC.QueryPerformanceFrequency(out frequency)
    if ret == 0
      raise WinError.new("QueryPerformanceFrequency")
    end

    frequency
  end

  def self.monotonic : {Int64, Int32}
    if LibC.QueryPerformanceCounter(out ticks) == 0
      raise WinError.new("QueryPerformanceCounter")
    end

    {ticks / @@performance_frequency, (ticks.remainder(NANOSECONDS_PER_SECOND) * NANOSECONDS_PER_SECOND / @@performance_frequency).to_i32}
  end

  def self.load_localtime : ::Time::Location?
    if LibC.GetTimeZoneInformation(out info) != LibC::TIME_ZONE_ID_UNKNOWN
      initialize_location_from_TZI(info)
    end
  end

  def self.zone_sources : Enumerable(String)
    [] of String
  end

  private def self.initialize_location_from_TZI(info)
    stdname, dstname = normalize_zone_names(info)

    if info.standardDate.wMonth == 0_u16
      # No DST
      zone = ::Time::Location::Zone.new(stdname, info.bias * BIAS_TO_OFFSET_FACTOR, false)
      return ::Time::Location.new("Local", [zone])
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

    current_year = ::Time.utc_now.year

    (current_year - 100).upto(current_year + 100) do |year|
      tstamp = calculate_switchdate_in_year(year, first_date) - (zones[second_index].offset)
      transitions << ::Time::Location::ZoneTransition.new(tstamp, first_index, first_index == 0, false)

      tstamp = calculate_switchdate_in_year(year, second_date) - (zones[first_index].offset)
      transitions << ::Time::Location::ZoneTransition.new(tstamp, second_index, second_index == 0, false)
    end

    ::Time::Location.new("Local", zones, transitions)
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

    time = ::Time.utc(year, systemtime.wMonth, day, systemtime.wHour, systemtime.wMinute, systemtime.wSecond)
    i = systemtime.wDayOfWeek.to_i32 - time.day_of_week.to_i32

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

    time.epoch
  end

  # Normalizes the names of the standard and dst zones.
  private def self.normalize_zone_names(info : LibC::TIME_ZONE_INFORMATION) : Tuple(String, String)
    stdname = String.from_utf16(info.standardName.to_unsafe)

    if normalized_names = WINDOWS_ZONE_NAMES[stdname]?
      return normalized_names
    end

    dstname = String.from_utf16(info.daylightName.to_unsafe)

    if english_name = translate_zone_name(stdname, dstname)
      if normalized_names = WINDOWS_ZONE_NAMES[english_name]?
        return normalized_names
      end
    end

    # As a last resort, return the raw names as provided by TIME_ZONE_INFORMATION.
    # They are most probably localized and we couldn't find a translation.
    return stdname, dstname
  end

  # Searches the registry for an English name of a time zone named *stdname* or *dstname*
  # and returns the English name.
  private def self.translate_zone_name(stdname, dstname)
    # TODO: Needs implementation once there is access to the registry.
    nil
  end
end
