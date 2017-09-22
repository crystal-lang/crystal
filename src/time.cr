require "crystal/system/time"

# `Time` represents an instance in time. Here are some examples:
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
# # Creating a time instance with a date only
# Time.new(2016, 2, 15) # => 2016-02-15 00:00:00
#
# # Specifying a time
# Time.new(2016, 2, 15, 10, 20, 30) # => 2016-02-15 10:20:30 UTC
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
# Time.new(2015, 10, 10) - 5.days # => 2015-10-05 00:00:00
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

  # `Kind` represents a specified time zone.
  #
  # Initializing a `Time` instance with specified `Kind`:
  #
  # ```
  # time = Time.new(2016, 2, 15, 21, 1, 10, 0, Time::Kind::Local)
  # ```
  #
  # Alternatively, you can switch the `Kind` for any instance:
  #
  # ```
  # time.to_utc   # => 2016-02-15 21:00:00 UTC
  # time.to_local # => 2016-02-16 05:01:10 +0800
  # ```
  #
  # Inspection:
  #
  # ```
  # time.local? # => true
  # time.utc?   # => false
  # ```
  #
  enum Kind
    Unspecified = 0
    Utc         = 1
    Local       = 2
  end

  @seconds : Int64
  @nanoseconds : Int32
  @kind : Kind

  def self.new
    seconds, nanoseconds, offset = Time.compute_seconds_nanoseconds_and_offset
    new(seconds: seconds + offset, nanoseconds: nanoseconds, kind: Kind::Local)
  end

  def self.new(year, month, day, hour = 0, minute = 0, second = 0, nanosecond = 0, kind = Kind::Unspecified)
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

    new(seconds: seconds, nanoseconds: nanosecond.to_i, kind: kind)
  end

  # :nodoc:
  def self.new(time : LibC::Timespec, kind = Kind::Unspecified)
    seconds = UNIX_SECONDS + time.tv_sec
    nanoseconds = time.tv_nsec.to_i
    new(seconds: seconds, nanoseconds: nanoseconds, kind: kind)
  end

  def initialize(*, @seconds : Int64, @nanoseconds : Int32, @kind : Kind)
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
  def self.epoch(seconds : Int) : self
    new(seconds: UNIX_SECONDS + seconds, nanoseconds: 0, kind: Kind::Utc)
  end

  # Returns a new `Time` instance that corresponds to the number
  # milliseconds elapsed since the unix epoch (00:00:00 UTC on 1 January 1970).
  #
  # ```
  # time = Time.epoch_ms(981173106789) # => 2001-02-03 04:05:06.789 UTC
  # time.millisecond                   # => 789
  # ```
  def self.epoch_ms(milliseconds : Int) : self
    milliseconds = milliseconds.to_i64
    seconds = UNIX_SECONDS + (milliseconds / 1_000)
    nanoseconds = (milliseconds % 1000) * NANOSECONDS_PER_MILLISECOND
    new(seconds: seconds, nanoseconds: nanoseconds.to_i, kind: Kind::Utc)
  end

  def clone
    self
  end

  def +(other : Span)
    add_span other.to_i, other.nanoseconds
  end

  def -(other : Span)
    add_span -other.to_i, -other.nanoseconds
  end

  def +(other : MonthSpan)
    add_months other.value
  end

  def -(other : MonthSpan)
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

    temp = Time.new(year, month, day, kind: kind)
    temp + time_of_day
  end

  def add_span(seconds, nanoseconds)
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

    unless 0 <= seconds <= MAX_SECONDS
      raise ArgumentError.new "Invalid time"
    end

    Time.new(seconds: seconds, nanoseconds: nanoseconds.to_i, kind: kind)
  end

  def -(other : Time)
    if local? && other.utc?
      self - other.to_local
    elsif utc? && other.local?
      self - other.to_utc
    else
      Span.new(
        seconds: total_seconds - other.total_seconds,
        nanoseconds: nanosecond - other.nanosecond,
      )
    end
  end

  def self.now : self
    new
  end

  def self.utc_now : self
    seconds, nanoseconds = compute_seconds_and_nanoseconds
    new(seconds: seconds, nanoseconds: nanoseconds, kind: Kind::Utc)
  end

  def date
    Time.new(year, month, day, kind: kind)
  end

  def year
    year_month_day_day_year[0]
  end

  def month
    year_month_day_day_year[1]
  end

  def day
    year_month_day_day_year[2]
  end

  def hour
    ((total_seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR).to_i
  end

  def minute
    ((total_seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE).to_i
  end

  def second
    (total_seconds % SECONDS_PER_MINUTE).to_i
  end

  def millisecond
    nanosecond / NANOSECONDS_PER_MILLISECOND
  end

  def nanosecond
    @nanoseconds
  end

  def time_of_day
    Span.new(nanoseconds: NANOSECONDS_PER_SECOND * (total_seconds % SECONDS_PER_DAY) + nanosecond)
  end

  def day_of_week
    value = ((total_seconds / SECONDS_PER_DAY) + 1) % 7
    DayOfWeek.new value.to_i
  end

  def day_of_year
    year_month_day_day_year[3]
  end

  # Returns `Kind` of the instance.
  def kind
    @kind
  end

  # Returns `true` if `Kind` is set to *Utc*.
  def utc?
    kind == Kind::Utc
  end

  # Returns `true` if `Kind` is set to *Local*.
  def local?
    kind == Kind::Local
  end

  def <=>(other : self)
    if utc? && other.local?
      self <=> other.to_utc
    elsif local? && other.utc?
      to_utc <=> other
    else
      cmp = total_seconds <=> other.total_seconds
      cmp = nanosecond <=> other.nanosecond if cmp == 0
      cmp
    end
  end

  def_hash total_seconds, nanosecond

  def self.days_in_month(year, month) : Int32
    unless 1 <= month <= 12
      raise ArgumentError.new "Invalid month"
    end

    unless 1 <= year <= 9999
      raise ArgumentError.new "Invalid year"
    end

    days = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH
    days[month]
  end

  def self.leap_year?(year) : Bool
    unless 1 <= year <= 9999
      raise ArgumentError.new "Invalid year"
    end

    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
  end

  def inspect(io : IO)
    Format.new("%F %T").format(self, io)

    case
    when utc?
      io << " UTC"
    when local?
      Format.new(" %:z").format(self, io) if local?
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
  def to_s(format : String, io : IO)
    Format.new(format).format(self, io)
  end

  # Parses a Time in the given *time* string, using the given *pattern* (see
  # `Time::Format`).
  #
  # ```
  # Time.parse("2016-04-05", "%F") # => 2016-04-05 00:00:00
  # ```
  def self.parse(time : String, pattern : String, kind = Time::Kind::Unspecified) : self
    Format.new(pattern, kind).parse(time)
  end

  # Returns the number of seconds since the Epoch for this time.
  #
  # ```
  # time = Time.parse("2016-01-12 03:04:05 UTC", "%F %T %z")
  # time.epoch # => 1452567845
  # ```
  def epoch : Int64
    (to_utc.total_seconds - UNIX_SECONDS).to_i64
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

  def to_utc
    if utc?
      self
    else
      Time.new(
        seconds: total_seconds - Time.compute_offset,
        nanoseconds: nanosecond,
        kind: Kind::Utc,
      )
    end
  end

  def to_local
    if local?
      self
    else
      Time.new(
        seconds: total_seconds + Time.compute_offset,
        nanoseconds: nanosecond,
        kind: Kind::Local,
      )
    end
  end

  private macro def_at(name)
    def at_{{name.id}}
      year, month, day, day_year = year_month_day_day_year
      {{yield}}
    end
  end

  def_at(beginning_of_year) { Time.new(year, 1, 1, kind: kind) }
  def_at(beginning_of_semester) { Time.new(year, ((month - 1) / 6) * 6 + 1, 1, kind: kind) }
  def_at(beginning_of_quarter) { Time.new(year, ((month - 1) / 3) * 3 + 1, 1, kind: kind) }
  def_at(beginning_of_month) { Time.new(year, month, 1, kind: kind) }
  def_at(beginning_of_day) { Time.new(year, month, day, kind: kind) }
  def_at(beginning_of_hour) { Time.new(year, month, day, hour, kind: kind) }
  def_at(beginning_of_minute) { Time.new(year, month, day, hour, minute, kind: kind) }

  def at_beginning_of_week
    dow = day_of_week.value
    if dow == 0
      (self - 6.days).at_beginning_of_day
    else
      (self - (dow - 1).days).at_beginning_of_day
    end
  end

  def_at(end_of_year) { Time.new(year, 12, 31, 23, 59, 59, 999, kind: kind) }

  def at_end_of_semester
    year, month = year_month_day_day_year
    if month <= 6
      month, day = 6, 30
    else
      month, day = 12, 31
    end
    Time.new(year, month, day, 23, 59, 59, 999, kind: kind)
  end

  def at_end_of_quarter
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
    Time.new(year, month, day, 23, 59, 59, 999, kind: kind)
  end

  def_at(end_of_month) { Time.new(year, month, Time.days_in_month(year, month), 23, 59, 59, 999, kind: kind) }

  def at_end_of_week
    dow = day_of_week.value
    if dow == 0
      at_end_of_day
    else
      (self + (7 - dow).days).at_end_of_day
    end
  end

  def_at(end_of_day) { Time.new(year, month, day, 23, 59, 59, 999, kind: kind) }
  def_at(end_of_hour) { Time.new(year, month, day, hour, 59, 59, 999, kind: kind) }
  def_at(end_of_minute) { Time.new(year, month, day, hour, minute, 59, 999, kind: kind) }
  def_at(midday) { Time.new(year, month, day, 12, 0, 0, 0, kind: kind) }

  {% for name, index in %w(sunday monday tuesday wednesday thursday friday saturday) %}
    def {{name.id}}?
      day_of_week.value == {{index}}
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

  private def year_month_day_day_year
    m = 1

    days = DAYS_MONTH
    totaldays = total_seconds / SECONDS_PER_DAY

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

  # Returns the local time offset in minutes relative to GMT.
  #
  # ```
  # # Assume in Argentina, where it's GMT-3
  # Time.local_offset_in_minutes # => -180
  # ```
  def self.local_offset_in_minutes
    compute_offset / SECONDS_PER_MINUTE
  end

  # Returns `seconds, nanoseconds, offset` where
  # `offset` is the number of seconds for now's timezone offset.
  protected def self.compute_seconds_nanoseconds_and_offset
    seconds, nanoseconds = compute_seconds_and_nanoseconds
    offset = compute_offset(seconds)
    {seconds, nanoseconds, offset}
  end

  protected def self.compute_offset
    seconds, nanoseconds = compute_seconds_and_nanoseconds
    compute_offset(seconds)
  end

  private def self.compute_offset(seconds)
    Crystal::System::Time.compute_utc_offset(seconds)
  end

  private def self.compute_seconds_and_nanoseconds
    Crystal::System::Time.compute_utc_seconds_and_nanoseconds
  end
end

require "./time/**"
