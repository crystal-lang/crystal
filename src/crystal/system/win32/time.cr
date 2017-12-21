require "c/winbase"
require "winerror"

module Crystal::System::Time
  # Win32 epoch is 1601-01-01 00:00:00 UTC
  WINDOWS_EPOCH_IN_SECONDS = 50_491_123_200_i64

  # Resolution of FILETIME is 100 nanoseconds
  NANOSECONDS_PER_FILETIME_TICK = 100

  NANOSECONDS_PER_SECOND    = 1_000_000_000
  FILETIME_TICKS_PER_SECOND = NANOSECONDS_PER_SECOND / NANOSECONDS_PER_FILETIME_TICK

  # TODO: For now, this method returns the UTC offset currently in place, ignoring *seconds*.
  def self.compute_utc_offset(seconds : Int64) : Int32
    ret = LibC.GetTimeZoneInformation(out zone_information)
    raise WinError.new("GetTimeZoneInformation") if ret == -1

    zone_information.bias.to_i32 * -60
  end

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
end
