require "crystal/system/time"

# `Time` represents an instance in incremental time. Here are some examples:
#
# ### Basic Usage
#
# ```
# time = Time.new(2016, 2, 15, 10, 20, 30)
#
# time.year    # => 2016
# time.month   # => 2
# time.day     # => 15
# time.hour    # => 10
# time.minute  # => 20
# time.second  # => 30
# time.monday? # => true
#
# # Creating a time instance with a date only in local timezone `Time::Location.local`.
# # The examples show an offset of `+01:00` but that can vary depending on
# Time.new(2016, 2, 15) # => 2016-02-15 00:00:00 +01:00
#
# # Specifying a time
# Time.new(2016, 2, 15, 10, 20, 30) # => 2016-02-15 10:20:30 +01:00
#
# # Creating a time instance in UTC
# Time.utc(2016, 2, 15, 10, 20, 30) # => 2016-02-15 10:20:30 UTC
# ```
#
# ### Formatting Time
#
# The `to_s` method returns a `String` value in the assigned format.
#
# ```
# time = Time.new(2015, 10, 12)
# time.to_s("%Y-%m-%d") # => "2015-10-12"
# ```
#
# See `Time::Format` for all the directives.
#
# ### Calculation
#
# ```
# Time.new(2015, 10, 10) - 5.days # => 2015-10-05 00:00:00 +01:00
#
# # Time calculation returns a Time::Span instance
# span = Time.new(2015, 10, 10) - Time.new(2015, 9, 10)
# span.days          # => 30
# span.total_hours   # => 720
# span.total_minutes # => 43200
#
# # Calculation between Time::Span instances
# span_a = Time::Span.new(3, 0, 0)
# span_b = Time::Span.new(2, 0, 0)
# span = span_a - span_b
# span       # => 01:00:00
# span.class # => Time::Span
# span.hours # => 1
# ```
struct Time
  class FloatingTimeConversionError < Exception
  end

  include Comparable(self)

  # :nodoc:
  DAYS_MONTH = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

  # :nodoc:
  DAYS_MONTH_LEAP = {0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

  # :nodoc:
  SECONDS_PER_MINUTE = 60

  # :nodoc:
  SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE

  # :nodoc:
  SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

  # :nodoc:
  SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY

  # :nodoc:
  NANOSECONDS_PER_MILLISECOND = 1_000_000_i64

  # :nodoc:
  NANOSECONDS_PER_SECOND = 1_000_000_000_i64

  # :nodoc:
  NANOSECONDS_PER_MINUTE = NANOSECONDS_PER_SECOND * 60

  # :nodoc:
  NANOSECONDS_PER_HOUR = NANOSECONDS_PER_MINUTE * 60

  # :nodoc:
  NANOSECONDS_PER_DAY = NANOSECONDS_PER_HOUR * 24

  # :nodoc:
  DAYS_PER_400_YEARS = 365*400 + 97

  # :nodoc:
  DAYS_PER_100_YEARS = 365*100 + 24

  # :nodoc:
  DAYS_PER_4_YEARS = 365*4 + 1

  # :nodoc:
  UNIX_SECONDS = SECONDS_PER_DAY.to_i64 * (1969*365 + 1969/4 - 1969/100 + 1969/400)

  # :nodoc:
  MAX_SECONDS = 315537897599_i64

  # `DayOfWeek` represents the day.
  #
  # ```
  # time = Time.new(2016, 2, 15)
  # time.day_of_week # => Time::DayOfWeek::Monday
  # ```
  #
  # Alternatively, you can use question methods:
  #
  # ```
  # time.friday? # => false
  # time.monday? # => true
  # ```
  enum DayOfWeek
    Sunday
    Monday
    Tuesday
    Wednesday
    Thursday
    Friday
    Saturday
  end

  @seconds : Int64
  @nanoseconds : Int32
  @location : Location

  # Returns a clock from an unspecified starting point, but strictly linearly
  # increasing. This clock should be independent from discontinuous jumps in the
  # system time, such as leap seconds, time zone adjustments or manual changes
  # to the computer's time.
  #
  # For example, the monotonic clock must always be used to measure an elapsed
  # time.
  def self.monotonic : Time::Span
    seconds, nanoseconds = Crystal::System::Time.monotonic
    Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
  end

  # Measures how long the block took to run. Relies on `monotonic` to not be
  # affected by time fluctuations.
  def self.measure : Time::Span
    start = monotonic
    yield
    monotonic - start
  end

  def self.new(location = Location.local)
    seconds, nanoseconds = Crystal::System::Time.compute_utc_seconds_and_nanoseconds
    new(seconds: seconds, nanoseconds: nanoseconds, location: location)
  end

  def self.new(year, month, day, hour = 0, minute = 0, second = 0, *, nanosecond = 0, location = Location.local)
    unless 1 <= year <= 9999 &&
           1 <= month <= 12 &&
           1 <= day <= Time.days_in_month(year, month) &&
           0 <= hour <= 23 &&
           0 <= minute <= 59 &&
           0 <= second <= 59 &&
           0 <= nanosecond <= 999_999_999
      raise ArgumentError.new "Invalid time"
    end

    days = absolute_days(year, month, day)

    seconds = 1_i64 *
              SECONDS_PER_DAY * days +
              SECONDS_PER_HOUR * hour +
              SECONDS_PER_MINUTE * minute +
              second

    # Normalize internal representation to UTC
    seconds = seconds - zone_offset_at(seconds, location)

    new(seconds: seconds, nanoseconds: nanosecond.to_i, location: location)
  end

  {% unless flag?(:win32) %}
    # :nodoc:
    def self.new(time : LibC::Timespec, location = Location.local)
      seconds = UNIX_SECONDS + time.tv_sec
      nanoseconds = time.tv_nsec.to_i
      new(seconds: seconds, nanoseconds: nanoseconds, location: location)
    end
  {% end %}

  def initialize(*, @seconds : Int64, @nanoseconds : Int32, @location : Location)
    unless 0 <= offset_seconds <= MAX_SECONDS
      raise ArgumentError.new "Invalid time: seconds out of range"
    end

    unless 0 <= @nanoseconds < NANOSECONDS_PER_SECOND
      raise ArgumentError.new "Invalid time: nanoseconds out of range"
    end
  end

  # Returns a new `Time` instance that corresponds to the number
  # seconds elapsed since the unix epoch (00:00:00 UTC on 1 January 1970).
  #
  # ```
  # Time.epoch(981173106) # => 2001-02-03 04:05:06 UTC
  # ```
  def self.epoch(seconds : Int) : Time
    utc(seconds: UNIX_SECONDS + seconds, nanoseconds: 0)
  end

  # Returns a new `Time` instance that corresponds to the number
  # milliseconds elapsed since the unix epoch (00:00:00 UTC on 1 January 1970).
  #
  # ```
  # time = Time.epoch_ms(981173106789) # => 2001-02-03 04:05:06.789 UTC
  # time.millisecond                   # => 789
  # ```
  def self.epoch_ms(milliseconds : Int) : Time
    milliseconds = milliseconds.to_i64
    seconds = UNIX_SECONDS + (milliseconds / 1_000)
    nanoseconds = (milliseconds % 1000) * NANOSECONDS_PER_MILLISECOND
    utc(seconds: seconds, nanoseconds: nanoseconds.to_i)
  end

  # Returns a new `Time` instance at the specified time in UTC time zone.
  def self.utc(year, month, day, hour = 0, minute = 0, second = 0, *, nanosecond = 0) : Time
    new(year, month, day, hour, minute, second, nanosecond: nanosecond, location: Location::UTC)
  end

  # Returns a new `Time` instance at the specified time in UTC time zone.
  def self.utc(*, seconds : Int64, nanoseconds : Int32) : Time
    new(seconds: seconds, nanoseconds: nanoseconds, location: Location::UTC)
  end

  def clone : self
    self
  end

  # Returns a `Time` that is later than this `Time` by the `Time::Span` *span*.
  def +(span : Time::Span) : Time
    add_span span.to_i, span.nanoseconds
  end

  # Returns a `Time` that is earlier than this `Time` by the `Time::Span` *span*.
  def -(span : Time::Span) : Time
    add_span -span.to_i, -span.nanoseconds
  end

  # Adds a number of months specified by *other*'s value.
  def +(other : Time::MonthSpan) : Time
    add_months other.value
  end

  # Subtracts a number of months specified by *other*'s value.
  def -(other : Time::MonthSpan) : Time
    add_months -other.value
  end

  private def add_months(months)
    day = self.day
    month = self.month + months.remainder(12)
    year = self.year + months.tdiv(12)

    if month < 1
      month = 12 + month
      year -= 1
    elsif month > 12
      month = month - 12
      year += 1
    end

    maxday = Time.days_in_month(year, month)
    if day > maxday
      day = maxday
    end

    temp = Time.new(year, month, day, location: location)
    temp + time_of_day
  end

  # Returns a `Time` that is this number of *seconds* and *nanoseconds* later.
  #
  # Negative values are subtracted, meaning an earlier point in time.
  def add_span(seconds : Int, nanoseconds : Int) : Time
    if seconds == 0 && nanoseconds == 0
      return self
    end

    seconds = total_seconds + seconds
    nanoseconds = self.nanosecond.to_i64 + nanoseconds

    # Nanoseconds might end up outside the min/max nanosecond
    # range, so take care of that
    seconds += nanoseconds.tdiv(NANOSECONDS_PER_SECOND)
    nanoseconds = nanoseconds.remainder(NANOSECONDS_PER_SECOND)

    if nanoseconds < 0
      seconds -= 1
      nanoseconds += NANOSECONDS_PER_SECOND
    end

    Time.new(seconds: seconds, nanoseconds: nanoseconds.to_i, location: location)
  end

  # Returns the amount of time between *other* and `self`.
  #
  # The amount can be negative if `self` is a `Time` that happens before *other*.
  def -(other : Time) : Time::Span
    Span.new(
      seconds: total_seconds - other.total_seconds,
      nanoseconds: nanosecond - other.nanosecond,
    )
  end

  # Returns the current time in the time zone currently observed in *location*,
  # using local time zone by default.
  def self.now(location = Location.local) : Time
    new(location)
  end

  # Returns the current time in UTC time zone.
  def self.utc_now : Time
    now(Location::UTC)
  end

  # Returns a copy of `self` with time-of-day components (hour, minute, ...) set to zero.
  def date : Time
    Time.new(year, month, day, location: location)
  end

  # Returns the year number (in the Common Era).
  def year : Int32
    year_month_day_day_year[0]
  end

  # Returns the month number of the year (`1..12`).
  def month : Int32
    year_month_day_day_year[1]
  end

  # Returns the day number of the month (`1..31`).
  def day : Int32
    year_month_day_day_year[2]
  end

  # Returns the hour of the day (`0..23`).
  def hour : Int32
    ((offset_seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR).to_i
  end

  # Returns the minute of the hour (`0..59`).
  def minute : Int32
    ((offset_seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE).to_i
  end

  # Returns the second of the minute (`0..59`).
  def second : Int32
    (offset_seconds % SECONDS_PER_MINUTE).to_i
  end

  # Returns the millisecond of the second (`0..999`).
  def millisecond : Int32
    nanosecond / NANOSECONDS_PER_MILLISECOND
  end

  # Returns the nanosecond of the second (`0..999_999_999`).
  def nanosecond : Int32
    @nanoseconds
  end

  # Returns how much time has passed since midnight of this day.
  def time_of_day : Time::Span
    Span.new(nanoseconds: NANOSECONDS_PER_SECOND * (offset_seconds % SECONDS_PER_DAY) + nanosecond)
  end

  # Returns the day of the week (`Sunday..Saturday`).
  def day_of_week : Time::DayOfWeek
    value = ((offset_seconds / SECONDS_PER_DAY) + 1) % 7
    DayOfWeek.new value.to_i
  end

  # Returns the day number of the year (`1..365`, or `1..366` on leap years).
  def day_of_year : Int32
    year_month_day_day_year[3]
  end

  # Returns `Location` of the instance.
  def location : Location
    @location
  end

  # Returns the time zone in effect in `location` at this point in time.
  def zone
    location.lookup(self)
  end

  # Returns the offset from UTC (in seconds) in `location` at this point in time.
  def offset : Int32
    zone.offset
  end

  # Returns `true` if `#location` equals to `Location::UTC`.
  def utc? : Bool
    location.utc?
  end

  # Returns `true` if this time's `#location` equals to the current
  # local location as returned by `Location.local`.
  #
  # Since the system's settings may change during a programm's runtime,
  # the result may not be identical between different invocations.
  def local? : Bool
    location.local?
  end

  def <=>(other : self)
    cmp = total_seconds <=> other.total_seconds
    cmp = nanosecond <=> other.nanosecond if cmp == 0
    cmp
  end

  def ==(other : self)
    total_seconds == other.total_seconds && nanosecond == other.nanosecond
  end

  def_hash total_seconds, nanosecond

  # Returns how many days this *month* (`1..12`) of this *year* has (28, 29, 30 or 31).
  #
  # ```
  # Time.days_in_month(2016, 2) # => 29
  # Time.days_in_month(1990, 4) # => 30
  # ```
  def self.days_in_month(year : Int, month : Int) : Int32
    unless 1 <= month <= 12
      raise ArgumentError.new "Invalid month"
    end

    unless 1 <= year <= 9999
      raise ArgumentError.new "Invalid year"
    end

    days = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH
    days[month]
  end

  # Returns number of days in *year*.
  #
  # ```
  # Time.days_in_year(1990) # => 365
  # Time.days_in_year(2004) # => 366
  # ```
  def self.days_in_year(year : Int) : Int32
    leap_year?(year) ? 366 : 365
  end

  # Returns whether this *year* is leap (February has one more day).
  def self.leap_year?(year : Int) : Bool
    unless 1 <= year <= 9999
      raise ArgumentError.new "Invalid year"
    end

    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
  end

  def inspect(io : IO)
    case
    when utc?
      to_s "%F %T UTC", io
    else
      if offset % 60 == 0
        to_s "%F %T %:z", io
      else
        to_s "%F %T %::z", io
      end
      io << ' ' << location.name unless location.fixed? || location.name == "Local"
    end
    io
  end

  # Formats this time using the given format (see `Time::Format`).
  #
  # ```
  # time = Time.new(2016, 4, 5)
  # time.to_s("%F") # => "2016-04-05"
  # ```
  def to_s(format : String) : String
    Format.new(format).format(self)
  end

  # Formats this time using the given format (see `Time::Format`)
  # into the given *io*.
  def to_s(format : String, io : IO) : Nil
    Format.new(format).format(self, io)
  end

  # Parses a Time in the given *time* string, using the given *pattern* (see
  # `Time::Format`).
  #
  # ```
  # Time.parse("2016-04-05", "%F") # => 2016-04-05 00:00:00 +01:00
  # ```
  def self.parse(time : String, pattern : String, location = nil) : Time
    Format.new(pattern, location).parse(time)
  end

  # Returns the number of seconds since the Epoch for this time.
  #
  # ```
  # time = Time.parse("2016-01-12 03:04:05 UTC", "%F %T %z")
  # time.epoch # => 1452567845
  # ```
  def epoch : Int64
    (total_seconds - UNIX_SECONDS).to_i64
  end

  # Returns the number of milliseconds since the Epoch for this time.
  #
  # ```
  # time = Time.parse("2016-01-12 03:04:05.678 UTC", "%F %T.%L %z")
  # time.epoch_ms # => 1452567845678
  # ```
  def epoch_ms : Int64
    epoch * 1_000 + (nanosecond / NANOSECONDS_PER_MILLISECOND)
  end

  # Returns the number of seconds since the Epoch for this time,
  # as a `Float64`.
  #
  # ```
  # time = Time.parse("2016-01-12 03:04:05.678 UTC", "%F %T.%L %z")
  # time.epoch_f # => 1452567845.678
  # ```
  def epoch_f : Float64
    epoch.to_f + nanosecond.to_f / 1e9
  end

  # Retuns this instance of time represented in `Location` *location*.
  #
  # ```
  # time = Time.new(2018, 1, 7, 15, 51, location: Time::Location.load("Europe/Berlin"))
  # time # => 2018-01-07 15:51:00 +01:00 Europe/Berlin
  # time = time.in(Time::Location.load("Australia/Sydney"))
  # time # => 2018-01-08 01:51:00 +11:00 Australia/Sydney
  # ```
  def in(location : Location) : Time
    return self if location == self.location

    Time.new(
      seconds: total_seconds,
      nanoseconds: nanosecond,
      location: location
    )
  end

  # Returns a copy of this `Time` converted to UTC.
  def to_utc : Time
    if utc?
      self
    else
      Time.utc(
        seconds: total_seconds,
        nanoseconds: nanosecond
      )
    end
  end

  # Returns a copy of this `Time` converted to the local time zone.
  def to_local : Time
    if local?
      self
    else
      in(Location.local)
    end
  end

  private macro def_at_beginning(interval)
    # Returns the time when the {{interval.id}} that contains `self` starts.
    def at_beginning_of_{{interval.id}} : Time
      year, month, day, day_year = year_month_day_day_year
      {{yield}}
    end
  end

  private macro def_at_end(interval)
    # Returns the time when the {{interval.id}} that includes `self` ends.
    def at_end_of_{{interval.id}} : Time
      year, month, day, day_year = year_month_day_day_year
      {{yield}}
    end
  end

  def_at_beginning(year) { Time.new(year, 1, 1, location: location) }
  def_at_beginning(semester) { Time.new(year, ((month - 1) / 6) * 6 + 1, 1, location: location) }
  def_at_beginning(quarter) { Time.new(year, ((month - 1) / 3) * 3 + 1, 1, location: location) }
  def_at_beginning(month) { Time.new(year, month, 1, location: location) }
  def_at_beginning(day) { Time.new(year, month, day, location: location) }
  def_at_beginning(hour) { Time.new(year, month, day, hour, location: location) }
  def_at_beginning(minute) { Time.new(year, month, day, hour, minute, location: location) }

  # Returns the time when the week that includes `self` starts.
  def at_beginning_of_week : Time
    dow = day_of_week.value
    if dow == 0
      (self - 6.days).at_beginning_of_day
    else
      (self - (dow - 1).days).at_beginning_of_day
    end
  end

  def_at_end(year) { Time.new(year, 12, 31, 23, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns the time when the half-year that includes `self` ends.
  def at_end_of_semester : Time
    year, month = year_month_day_day_year
    if month <= 6
      month, day = 6, 30
    else
      month, day = 12, 31
    end
    Time.new(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location)
  end

  # Returns the time when the quarter-year that includes `self` ends.
  def at_end_of_quarter : Time
    year, month = year_month_day_day_year
    if month <= 3
      month, day = 3, 31
    elsif month <= 6
      month, day = 6, 30
    elsif month <= 9
      month, day = 9, 30
    else
      month, day = 12, 31
    end
    Time.new(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location)
  end

  def_at_end(month) { Time.new(year, month, Time.days_in_month(year, month), 23, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns the time when the week that includes `self` ends.
  def at_end_of_week : Time
    dow = day_of_week.value
    if dow == 0
      at_end_of_day
    else
      (self + (7 - dow).days).at_end_of_day
    end
  end

  def_at_end(day) { Time.new(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location) }
  def_at_end(hour) { Time.new(year, month, day, hour, 59, 59, nanosecond: 999_999_999, location: location) }
  def_at_end(minute) { Time.new(year, month, day, hour, minute, 59, nanosecond: 999_999_999, location: location) }

  # Returns the midday (12:00) of the day represented by `self`.
  def at_midday : Time
    year, month, day = year_month_day_day_year
    Time.new(year, month, day, 12, 0, 0, nanosecond: 0, location: location)
  end

  {% for name in DayOfWeek.constants %}
    # Does `self` happen on {{name.id}}?
    def {{name.id.downcase}}? : Bool
      day_of_week.{{name.id.downcase}}?
    end
  {% end %}

  protected def self.absolute_days(year, month, day)
    days = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH

    temp = 0
    m = 1
    while m < month
      temp += days[m]
      m += 1
    end

    (day - 1) + temp + (365*(year - 1)) + ((year - 1)/4) - ((year - 1)/100) + ((year - 1)/400)
  end

  protected def total_seconds
    @seconds
  end

  protected def offset_seconds
    @seconds + offset
  end

  private def year_month_day_day_year
    m = 1

    days = DAYS_MONTH
    totaldays = offset_seconds / SECONDS_PER_DAY

    num400 = totaldays / DAYS_PER_400_YEARS
    totaldays -= num400 * DAYS_PER_400_YEARS

    num100 = totaldays / DAYS_PER_100_YEARS
    if num100 == 4 # leap
      num100 = 3
    end
    totaldays -= num100 * DAYS_PER_100_YEARS

    num4 = totaldays / DAYS_PER_4_YEARS
    totaldays -= num4 * DAYS_PER_4_YEARS

    numyears = totaldays / 365

    if numyears == 4 # leap
      numyears = 3
    end

    year = num400*400 + num100*100 + num4*4 + numyears + 1

    totaldays -= numyears * 365
    day_year = totaldays + 1

    if (numyears == 3) && ((num100 == 3) || !(num4 == 24)) # 31 dec leapyear
      days = DAYS_MONTH_LEAP
    end

    while totaldays >= days[m]
      totaldays -= days[m]
      m += 1
    end

    month = m
    day = totaldays + 1

    {year.to_i, month.to_i, day.to_i, day_year.to_i}
  end

  protected def self.zone_offset_at(seconds, location)
    unix = seconds - UNIX_SECONDS
    zone, range = location.lookup_with_boundaries(unix)

    if zone.offset != 0
      case utc = unix - zone.offset
      when .<(range[0])
        zone = location.lookup(range[0] - 1)
      when .>=(range[1])
        zone = location.lookup(range[1])
      end
    end

    zone.offset
  end
end

require "./time/**"
