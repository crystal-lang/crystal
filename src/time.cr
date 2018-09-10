require "crystal/system/time"

# `Time` represents a date-time instant in
# [incremental time](https://www.w3.org/International/articles/definitions-time/#incremental_time)
# observed in a specific time zone.
#
# The calendaric calculations are based on the rules of the proleptic Gregorian
# calendar as specified in [ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf).
# Leap seconds are ignored.
#
# Internally, the time is stored as an `Int64` representing seconds from epoch
# (`0001-01-01 00:00:00.0 UTC`) and an `Int32` representing
# nanosecond-of-second with value range `0..999_999_999`.
#
# The supported date range is `0001-01-01 00:00:00.0` to
# `9999-12-31 23:59:59.999_999_999` in any local time zone.
#
# ### Telling the Time
#
# There are several methods to retrieve a `Time` instance representing the
# current time:
#
# ```crystal
# Time.utc_now                                  # returns the current time in UTC
# Time.now Time::Location.load("Europe/Berlin") # returns the current time in time zone Europe/Berlin
# Time.now                                      # returns the current time in current time zone
# ```
#
# It is generally recommended to keep instances in UTC and only apply a
# local time zone when formatting for user display, unless the domain logic
# requires having a specific time zone (for example for calendaric operations).
#
# ### Creating a Specific Instant
#
# `Time` instances representing a specific instant can be created by
# `.utc` or `.new` with the date-time specified as individual arguments:
#
# ```
# time = Time.utc(2016, 2, 15, 10, 20, 30)
# time.to_s # => 2016-02-15 10:20:30 UTC
# time = Time.new(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))
# time.to_s # => 2016-02-15 10:20:30 +01:00 Europe/Berlin
# # The time-of-day can be omitted and defaults to midnight (start of day):
# time = Time.utc(2016, 2, 15)
# time.to_s # => 2016-02-15 00:00:00 UTC
# ```
#
# ### Retrieving Time Information
#
# Each `Time` instance allows querying calendar data:
#
# ```
# time = Time.utc(2016, 2, 15, 10, 20, 30)
# time.year        # => 2016
# time.month       # => 2
# time.day         # => 15
# time.hour        # => 10
# time.minute      # => 20
# time.second      # => 30
# time.millisecond # => 0
# time.nanosecond  # => 0
# time.day_of_week # => Time::DayOfWeek::Monday
# time.day_of_year # => 46
# time.monday?     # => true
# time.time_of_day # => 10:20:30
# ```
#
# ### Time Zones
#
# Each time is attached to a specific time zone, represented by a `Location`
# (see `#location`).
# `#zone` returns the time zone observed in this location at the current time
# (i.e. the instant represented by this `Time`).
# `#offset` returns the offset of the current zone in seconds.
#
# ```
# time = Time.new(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
# time          # => 2018-03-08 22:05:13 +01:00 Europe/Berlin
# time.location # => #<Time::Location Europe/Berlin>
# time.zone     # => #<Time::Location::Zone CET +01:00 (3600s) STD>
# time.offset   # => 3600
# ```
#
# Using `.utc`, the location is `Time::Location::UTC`:
#
# ```
# time = Time.utc(2018, 3, 8, 22, 5, 13)
# time          # => 2018-03-08 22:05:13.0 UTC
# time.location # => #<Time::Location UTC>
# time.zone     # => #<Time::Location::Zone UTC +00:00 (0s) STD>
# time.offset   # => 0
# ```
#
# A `Time` instance can be transformed to a different time zone while retaining
# the same instant using `#in`:
#
# ```
# time_de = Time.new(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
# time_ar = time_de.in Time::Location.load("America/Buenos_Aires")
# time_de # => 2018-03-08 22:05:13 +01:00 Europe/Berlin
# time_ar # => 2018-03-08 18:05:13 -03:00 America/Buenos_Aires
# ```
#
# Both `Time` instances show a different local date-time, but they represent
# the same date-time in the instant time-line, therefore they are considered
# equal:
#
# ```
# time_de.to_utc     # => 2018-03-08 21:05:13 UTC
# time_ar.to_utc     # => 2018-03-08 21:05:13 UTC
# time_de == time_ar # => true
# ```
#
# There are also two special methods for converting to UTC and local time zone:
#
# ```
# time.to_utc   # equals time.in(Location::UTC)
# time.to_local # equals time.in(Location.local)
# ```
#
# `#to_local_in` allows changing the time zone while keeping
# the same local date-time (wall clock) which results in a different instant
# on the time line.
#
# ### Formatting and Parsing Time
#
# To make date-time instances exchangeable between different computer systems
# or readable to humans, they are usually converted to and from a string
# representation.
#
# The method `#to_s` formats the date-time according to a specified pattern.
#
# ```
# time = Time.utc(2015, 10, 12, 10, 30, 0)
# time.to_s("%Y-%m-%d %H:%M:%S %:z") # => "2015-10-12 10:30:00 +00:00"
# ```
#
# Similarly, `Time.parse` is used to construct a `Time` instance from date-time
# information in a string, according to a specified pattern:
#
# ```
# Time.parse("2015-10-12 10:30:00 +00:00", "%Y-%m-%d %H:%M:%S %z")
# ```
#
# See `Time::Format` for all directives.
#
# ### Calculations
#
# ```
# Time.utc(2015, 10, 10) - 5.days # => 2015-10-05 00:00:00 +00:00
#
# span = Time.utc(2015, 10, 10) - Time.utc(2015, 9, 10)
# span.days          # => 30
# span.total_hours   # => 720
# span.total_minutes # => 43200
# ```
#
# ## Measuring Time
#
# The typical time representation provided by the operating system is based on
# a "wall clock" which is subject to changes for clock synchronization.
# This can result in discontinuous jumps in the time-line making it not
# suitable for accurately measuring elapsed time.
#
# Instances of `Time` are focused on telling time – using a "wall clock".
# When `Time.now` is called multiple times, the difference between the
# returned instances is not guranteed to equal to the time elapsed between
# making the calls; even the order of the returned `Time` instances might
# not reflect invocation order.
#
# ```
# t1 = Time.utc_now
# # operation that takes 1 minute
# t2 = Time.utc_now
# t2 - t1 # => ?
# ```
#
# The resulting `Time::Span` could be anything, even negative, if the
# computer's wall clock has changed between both calls.
#
# As an alternative, the operating system also provides a monotonic clock.
# It's time-line has no specfied starting point but is strictly linearly
# increasing.
#
# This monotonic clock should always be used for measuring elapsed time.
#
# A reading from this clock can be taken using `.monotonic`:
#
# ```
# t1 = Time.monotonic
# # operation that takes 1 minute
# t2 = Time.monotonic
# t2 - t1 # => 1.minute (approximately)
# ```
#
# The execution time of a block can be measured using `.measure`:
#
# ```
# elapsed_time = Time.measure do
#   # operation that takes 20 milliseconds
# end
# elapsed_time # => 20.milliseconds (approximately)
# ```
struct Time
  class FloatingTimeConversionError < Exception
  end

  include Comparable(Time)

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
  NANOSECONDS_PER_MICROSECOND = 1_000_i64

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

  # `DayOfWeek` represents a day-of-week in the Gregorian calendar.
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

  # Returns `Location` representing the time-zone observed by this `Time`.
  getter location : Location

  # Returns a reading from the monotonic clock to measure elapsed time.
  #
  # Values from the monotonic clock and wall clock are not comparable.
  # This method does not return a `Time` instance but a `Time::Span` amounting
  # to the number of nanoseconds elapsed since the unspecified starting point
  # of the monotonic clock.
  # The returned values are strictly linearly increasing.
  #
  # This clock should be independent from discontinuous jumps in the
  # system time, such as leap seconds, time zone adjustments or manual changes
  # to the computer's clock.
  #
  # Subtracting two results from this method equals to the time elapsed between
  # both readings:
  #
  # ```
  # start = Time.monotonic
  # # operation that takes 20 milliseconds
  # elapsed = Time.monotonic - start # => 20.milliseconds (approximately)
  # # operation that takes 50 milliseconds
  # elapsed_total = Time.monotonic - start # => 70.milliseconds (approximately)
  # ```
  #
  # The execution time of a block can be measured using `.measure`.
  def self.monotonic : Time::Span
    seconds, nanoseconds = Crystal::System::Time.monotonic
    Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
  end

  # Measures the execution time of *block*.
  #
  # The measurement relies on the monotonic clock and is not
  # affected by fluctuations of the system clock (see `#monotonic`).
  #
  # ```
  # elapsed_time = Time.measure do
  #   # operation that takes 20 milliseconds
  # end
  # elapsed_time # => 20.milliseconds (approximately)
  # ```
  def self.measure(&block : ->) : Time::Span
    start = monotonic
    yield
    monotonic - start
  end

  # Creates a new `Time` instance representing the current time from the
  # system clock observed in *location* (defaults to local time zone).
  def self.new(location : Location = Location.local) : Time
    seconds, nanoseconds = Crystal::System::Time.compute_utc_seconds_and_nanoseconds
    new(seconds: seconds, nanoseconds: nanoseconds, location: location)
  end

  # Creates a new `Time` instance representing the current time from the
  # system clock observed in *location* (defaults to local time zone).
  def self.now(location : Location = Location.local) : Time
    new(location)
  end

  # Creates a new `Time` instance representing the current time from the
  # system clock in UTC.
  def self.utc_now : Time
    now(Location::UTC)
  end

  # Creates a new `Time` instance representing the given local date-time in
  # *location* (defaults to local time zone).
  #
  # ```
  # time = Time.new(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))
  # time.inspect # => "2016-02-15 10:20:30.0 +01:00 Europe/Berlin"
  # ```
  #
  # Valid value ranges for the individual fields:
  #
  # * `year`: `1..9999`
  # * `month`: `1..12`
  # * `day`: `1` - `28`/`29`/`30`/`31` (depending on month and year)
  # * `hour`: `0..23`
  # * `minute`: `0..59`
  # * `second`: `0..59`
  # * `nanosecond`: `0..999_999_999`
  #
  # The time-of-day can be omitted and defaults to midnight (start of day):
  #
  # ```
  # time = Time.new(2016, 2, 15)
  # time.to_s # => "2016-02-15 00:00:00 +00:00"
  # ```
  #
  # The local date-time representation is resolved to a single instant based on
  # the offset observed in the *location* at this time.
  #
  # This process can sometimes be ambiguous, mostly due skipping or repeating
  # times at time zone transitions. For example, in `America/New_York` the
  # date-time `2011-03-13 02:15:00` never occured, there is a gap between time
  # zones. In return, `2011-11-06 01:15:00` occured twice because of overlapping
  # time zones.
  #
  # In such cases, the choice of time zone, and therefore the time, is not
  # well-defined. This method returns a time that is correct in one of the two
  # zones involved in the transition, but it does not guarantee which.
  def self.new(year : Int32, month : Int32, day : Int32, hour : Int32 = 0, minute : Int32 = 0, second : Int32 = 0, *, nanosecond : Int32 = 0, location : Location = Location.local) : Time
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

  # Creates a new `Time` instance representing the given date-time in UTC.
  #
  # ```
  # time = Time.utc(2016, 2, 15, 10, 20, 30)
  # time.to_s # => "2016-02-15 10:20:30 UTC"
  # ```
  #
  # Valid value ranges for the individual fields:
  #
  # * `year`: `1..9999`
  # * `month`: `1..12`
  # * `day`: `1` - `28`/`29`/`30`/`31` (depending on month and year)
  # * `hour`: `0..23`
  # * `minute`: `0..59`
  # * `second`: `0..59`
  # * `nanosecond`: `0..999_999_999`
  #
  # The time-of-day can be omitted and defaults to midnight (start of day):
  #
  # ```
  # time = Time.utc(2016, 2, 15)
  # time.to_s # => "2016-02-15 00:00:00 UTC"
  # ```
  #
  # Since UTC does not have any time zone transitions, each date-time is
  # unambiguously resolved.
  def self.utc(year : Int32, month : Int32, day : Int32, hour : Int32 = 0, minute : Int32 = 0, second : Int32 = 0, *, nanosecond : Int32 = 0) : Time
    new(year, month, day, hour, minute, second, nanosecond: nanosecond, location: Location::UTC)
  end

  # Creates a new `Time` instance that corresponds to the number of *seconds*
  # and *nanoseconds* elapsed from epoch (`0001-01-01 00:00:00.0 UTC`)
  # observed in *location*.
  #
  # Valid range for *seconds* is `0..315_537_897_599`.
  # For *nanoseconds* it is `0..999_999_999`.
  def initialize(*, @seconds : Int64, @nanoseconds : Int32, @location : Location)
    unless 0 <= offset_seconds <= MAX_SECONDS
      raise ArgumentError.new "Invalid time: seconds out of range"
    end

    unless 0 <= @nanoseconds < NANOSECONDS_PER_SECOND
      raise ArgumentError.new "Invalid time: nanoseconds out of range"
    end
  end

  # Creates a new `Time` instance that corresponds to the number of *seconds*
  # and *nanoseconds* elapsed from epoch (`0001-01-01 00:00:00.0 UTC`)
  # in UTC.
  #
  # Valid range for *seconds* is `0..315_537_897_599`.
  # For *nanoseconds* it is `0..999_999_999`.
  def self.utc(*, seconds : Int64, nanoseconds : Int32) : Time
    new(seconds: seconds, nanoseconds: nanoseconds, location: Location::UTC)
  end

  {% unless flag?(:win32) %}
    # :nodoc:
    def self.new(time : LibC::Timespec, location : Location = Location.local)
      seconds = UNIX_SECONDS + time.tv_sec
      nanoseconds = time.tv_nsec.to_i
      new(seconds: seconds, nanoseconds: nanoseconds, location: location)
    end
  {% end %}

  # Creates a new `Time` instance that corresponds to the number of
  # *seconds* elapsed since the Unix epoch (`1970-01-01 00:00:00 UTC`).
  #
  # The time zone is always UTC.
  #
  # ```
  # Time.epoch(981173106) # => 2001-02-03 04:05:06 UTC
  # ```
  def self.epoch(seconds : Int) : Time
    utc(seconds: UNIX_SECONDS + seconds, nanoseconds: 0)
  end

  # Creates a new `Time` instance that corresponds to the number of
  # *milliseconds* elapsed since the Unix epoch (`1970-01-01 00:00:00 UTC`).
  #
  # The time zone is always UTC.
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

  # Creates a new `Time` instance with the same local date-time representation
  # (wall clock) in a different *location*.
  #
  # Unlike `#in`, which always preserves the same instant in time, `#to_local_in`
  # adjusts the instant such that it results in the same local date-time
  # representation. Both instants are apart from each other by the difference in
  # zone offsets.
  #
  # ```
  # new_year = Time.utc(2019, 1, 1, 0, 0, 0)
  # tokyo = new_year.to_local_in(Time::Location.load("Asia/Tokyo"))
  # new_york = new_year.to_local_in(Time::Location.load("America/New_York"))
  # tokyo.to_s    # => 2019-01-01 00:00:00.0 +09:00 Asia/Tokyo
  # new_york.to_s # => 2019-01-01 00:00:00.0 -05:00 America/New_York
  # ```
  def to_local_in(location : Location)
    local_seconds = offset_seconds
    local_seconds -= Time.zone_offset_at(local_seconds, location)

    Time.new(seconds: local_seconds, nanoseconds: nanosecond, location: location)
  end

  def clone : Time
    self
  end

  # Returns a copy of this `Time` with *span* added.
  #
  # See `#add_span` for details.
  def +(span : Time::Span) : Time
    add_span span.to_i, span.nanoseconds
  end

  # Returns a copy of this `Time` with *span* subtracted.
  #
  # See `#add_span` for details.
  def -(span : Time::Span) : Time
    add_span -span.to_i, -span.nanoseconds
  end

  # Returns a copy of this `Time` with *span* added.
  #
  # It adds the number of months with overflow increasing the year.
  # If the resulting day-of-month would be invalid, it is adjusted to the last
  # valid day of the moneth.
  #
  # For example, adding `1.month` to `2007-03-31` would result in the invalid
  # date `2007-04-31` which will be adjusted to `2007-04-30`.
  #
  # This operates on the local time-line, such that the local date-time
  # represenations of month and year are increased by the specified amount.
  #
  # If the resulting date-time is ambiguous due to time zone transitions,
  # a correct time will be returned, but it does not guarantee which.
  def +(span : Time::MonthSpan) : Time
    add_months span.value
  end

  # Returns a copy of this `Time` with *span* subtracted.
  #
  # It adds the number of months with overflow decreasing the year.
  # If the resulting day-of-month would be invalid, it is adjusted to the last
  # valid day of the moneth.
  #
  # For example, subtracting `1.month` from `2007-05-31` would result in the invalid
  # date `2007-04-31` which will be adjusted to `2007-04-30`.
  #
  # This operates on the local time-line, such that the local date-time
  # represenations of month and year are decreased by the specified amount.
  #
  # If the resulting date-time is ambiguous due to time zone transitions,
  # a correct time will be returned, but it does not guarantee which.
  def -(span : Time::MonthSpan) : Time
    add_months -span.value
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

  # Returns a copy of this `Time` with the number of *seconds* and
  # *nanoseconds* added.
  #
  # Positive values result in a later time, negative values in an earlier time.
  #
  # This operates on the instant time-line, such that adding the eqivalent of
  # one hour will always be a duration of one hour later.
  # The local date-time representation may change by a different amount,
  # depending on time zone transitions.
  #
  # Overflow in *nanoseconds* will be transferred to *seconds*.
  #
  # There is no explicit limit on the input values but the addition must result
  # in a valid time between `0001-01-01 00:00:00.0` and
  # `9999-12-31 23:59:59.999_999_999`. Otherwise `ArgumentError` is raised.
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

  # Returns a `Time::Span` amounting to the duration between *other* and `self`.
  #
  # The time span is negative if `self` is before *other*.
  #
  # The duration amounts to the actual time elapsed between both instances, on
  # the instant time-line.
  # The difference between local date-time representations may equal to a
  # different duration, depending on time zone transitions.
  def -(other : Time) : Time::Span
    Span.new(
      seconds: total_seconds - other.total_seconds,
      nanoseconds: nanosecond - other.nanosecond,
    )
  end

  # Returns a copy of `self` with time-of-day components (hour, minute, second,
  # nanoseconds) set to zero.
  #
  # This equals `at_beginning_of_day` or
  # `Time.new(year, month, day, 0, 0, 0, nanoseconds: 0, location: location)`.
  def date : Time
    Time.new(year, month, day, location: location)
  end

  # Returns the year of the proleptic Georgian Calendar (`0..9999`).
  def year : Int32
    year_month_day_day_year[0]
  end

  # Returns the month of the year (`1..12`).
  def month : Int32
    year_month_day_day_year[1]
  end

  # Returns the day of the month (`1..31`).
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

  # Returns the duration between this `Time` and midnight of the same day.
  #
  # This is equivalent to creating a `Time::Span` from the time-of-day fields:
  #
  # ```
  # time.time_of_day == Time::Span.new(time.hour, time.minute, time.second, time.nanosecond)
  # ```
  def time_of_day : Time::Span
    Span.new(nanoseconds: NANOSECONDS_PER_SECOND * (offset_seconds % SECONDS_PER_DAY) + nanosecond)
  end

  # Returns the day of the week (`Sunday..Saturday`).
  def day_of_week : Time::DayOfWeek
    value = ((offset_seconds / SECONDS_PER_DAY) + 1) % 7
    DayOfWeek.new value.to_i
  end

  # Returns the day of the year.
  #
  # The value range is `1..365` in normal yars and `1..366` in leap years.
  def day_of_year : Int32
    year_month_day_day_year[3]
  end

  # Returns the time zone in effect in `location` at this instant.
  def zone : Time::Location::Zone
    location.lookup(self)
  end

  # Returns the offset from UTC (in seconds) in effect in `location` at
  # this instant.
  def offset : Int32
    zone.offset
  end

  # Returns `true` if `#location` equals to `Location::UTC`.
  def utc? : Bool
    location.utc?
  end

  # Returns `true` if `#location` equals to the local time zone
  # (`Time::Location.local`).
  #
  # Since the system's settings may change during a programm's runtime,
  # the result may not be identical between different invocations.
  def local? : Bool
    location.local?
  end

  # Compares this `Time` with *other*.
  #
  # The comparison is based on the instant time-line, even if the local
  # date-time representation (wall clock) would compare differently.
  #
  # To ensure the comparison is also true for local wall clock, both date-times
  # need to be transforemd to the same time zone.
  def <=>(other : Time) : Int32
    cmp = total_seconds <=> other.total_seconds
    cmp = nanosecond <=> other.nanosecond if cmp == 0
    cmp
  end

  # Compares this `Time` with *other* for equality.
  #
  # Two instances are considered equal if they represent the same date-time in
  # the instant time-line, even if they show a different local date-time.
  #
  # ```
  # time_de = Time.new(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
  # time_ar = Time.new(2018, 3, 8, 18, 5, 13, location: Time::Location.load("America/Buenos_Aires"))
  # time_de == time_ar # => true
  #
  # # both times represent the same instant:
  # time_de.to_utc # => 2018-03-08 21:05:13 UTC
  # time_ar.to_utc # => 2018-03-08 21:05:13 UTC
  # ```
  def ==(other : Time) : Bool
    total_seconds == other.total_seconds && nanosecond == other.nanosecond
  end

  def_hash total_seconds, nanosecond

  # Returns the number of days in *month* (value range: `1..12`) taking account
  # of the *year*.
  #
  # The returned value is either `28`, `29`, `30` or `31` depending on the
  # month and whether *year* is leap.
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

  # Returns the number of days in *year*.
  #
  # A normal year has `365` days, a leap year `366` days.
  #
  # ```
  # Time.days_in_year(1990) # => 365
  # Time.days_in_year(2004) # => 366
  # ```
  def self.days_in_year(year : Int) : Int32
    leap_year?(year) ? 366 : 365
  end

  # Returns `true` if *year* is a leap year in the proleptic Gregorian
  # calendar.
  def self.leap_year?(year : Int) : Bool
    unless 1 <= year <= 9999
      raise ArgumentError.new "Invalid year"
    end

    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  end

  # Prints this `Time` to *io*.
  #
  # The local date-time is formatted as date string `YYYY-MM-DD HH:mm:ss.nnnnnnnnn +ZZ:ZZ:ZZ`.
  # Nanoseconds are omitted if *with_nanoseconds* is `false`.
  # When the location is `UTC`, the offset is omitted. Offset seconds are omitted if `0`.
  #
  # The name of the location is appended unless it is a fixed zone offset.
  def inspect(io : IO, with_nanoseconds = true)
    to_s "%F %T", io

    if with_nanoseconds
      if @nanoseconds == 0
        io << ".0"
      else
        to_s ".%N", io
      end
    end

    if utc?
      io << " UTC"
    else
      io << ' '
      zone.format(io)
      io << ' ' << location.name unless location.fixed?
    end

    io
  end

  # Prints this `Time` to *io*.
  #
  # The local date-time is formatted as date string `YYYY-MM-DD HH:mm:ss +ZZ:ZZ:ZZ`.
  # Nanoseconds are always omitted.
  # When the location is `UTC`, the offset is replaced with the string `UTC`.
  # Offset seconds are omitted if `0`.
  def to_s(io : IO)
    to_s("%F %T ", io)

    if utc?
      io << "UTC"
    else
      zone.format(io)
    end
  end

  # Formats this `Time` according to the pattern in *format*.
  #
  # See `Time::Format` for details.
  #
  # ```
  # time = Time.new(2016, 4, 5)
  # time.to_s("%F") # => "2016-04-05"
  # ```
  def to_s(format : String) : String
    Format.new(format).format(self)
  end

  # Formats this `Time` according to the pattern in *format* to the given *io*.
  #
  # See `Time::Format` for details.
  def to_s(format : String, io : IO) : Nil
    Format.new(format).format(self, io)
  end

  # Format this time using the format specified by [RFC 3339](https://tools.ietf.org/html/rfc3339) ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  #
  # ```
  # Time.utc(2016, 2, 15).to_rfc3339 # => "2016-02-15T00:00:00Z"
  # ```
  #
  # ISO 8601 allows some freedom over the syntax and RFC 3339 exercises that
  # freedom to rigidly define a fixed format intended for use in internet
  # protocols and standards.
  def to_rfc3339
    Format::RFC_3339.format(to_utc)
  end

  # Format this time using the format specified by [RFC 3339](https://tools.ietf.org/html/rfc3339) ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  # into the given *io*.
  def to_rfc3339(io : IO)
    Format::RFC_3339.format(to_utc, io)
  end

  # Parse time format specified by [RFC 3339](https://tools.ietf.org/html/rfc3339) ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  def self.parse_rfc3339(time : String)
    Format::RFC_3339.parse(time)
  end

  # Parse datetime format specified by [ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf).
  #
  # This is similar to `.parse_rfc3339` but RFC 3339 defines a more strict format.
  # In ISO 8601 for examples, field delimiters (`-`, `:`) are optional.
  #
  # Use `#to_rfc3339` to format a `Time` according to .
  def self.parse_iso8601(time : String)
    Format::ISO_8601_DATE_TIME.parse(time)
  end

  # Format this time using the format specified by [RFC 2822](https://www.ietf.org/rfc/rfc2822.txt).
  #
  # ```
  # Time.utc(2016, 2, 15).to_rfc2822 # => "Mon, 15 Feb 2016 00:00:00 +0000"
  # ```
  #
  # This is also compatible to [RFC 882](https://tools.ietf.org/html/rfc882) and [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
  def to_rfc2822
    Format::RFC_2822.format(to_utc)
  end

  # Format this time using the format specified by [RFC 2822](https://www.ietf.org/rfc/rfc2822.txt)
  # into the given *io*.
  #
  # This is also compatible to [RFC 882](https://tools.ietf.org/html/rfc882) and [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
  def to_rfc2822(io : IO)
    Format::RFC_2822.format(to_utc, io)
  end

  # Parse time format specified by [RFC 2822](https://www.ietf.org/rfc/rfc2822.txt).
  #
  # This is also compatible to [RFC 882](https://tools.ietf.org/html/rfc882) and [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
  def self.parse_rfc2822(time : String)
    Format::RFC_2822.parse(time)
  end

  # Parses a `Time` from *time* string using the given *pattern*.
  #
  # See `Time::Format` for details.
  #
  # ```
  # Time.parse("2016-04-05", "%F", Time::Location.load("Europe/Berlin")) # => 2016-04-05 00:00:00.0 +02:00 Europe/Berlin
  # ```
  #
  # If there is no time zone information in the formatted time, *location* will
  # be assumed. When *location* is `nil`, in such a case the parser will raise
  # `Time::Format::Error`.
  def self.parse(time : String, pattern : String, location : Location) : Time
    Format.new(pattern, location).parse(time)
  end

  # Parses a `Time` from *time* string using the given *pattern*.
  #
  # See `Time::Format` for details.
  #
  # ```
  # Time.parse!("2016-04-05 +00:00", "%F %:z") # => 2016-04-05 00:00:00.0 +00:00
  # Time.parse!("2016-04-05", "%F")            # raises Time::Format::Error
  # ```
  #
  # If there is no time zone information in the formatted time, the parser will raise
  # `Time::Format::Error`.
  def self.parse!(time : String, pattern : String) : Time
    Format.new(pattern, nil).parse(time)
  end

  # Parses a `Time` from *time* string using the given *pattern* and
  # `Time::Location::UTC` as default location.
  #
  # See `Time::Format` for details.
  #
  # ```
  # Time.parse_utc("2016-04-05", "%F") # => 2016-04-05 00:00:00.0 +00:00
  # ```
  #
  # `Time::Location::UTC` will only be used as `location` if the formatted time
  # does not contain any time zone information. The return value can't be
  # assumed to be a UTC time (this can be achieved by calling `#to_utc`).
  def self.parse_utc(time : String, pattern : String) : Time
    parse(time, pattern, Location::UTC)
  end

  # Parses a `Time` from *time* string using the given *pattern* and
  # `Time::Location.local` asdefault location
  #
  # See `Time::Format` for details.
  #
  # ```
  # Time.parse_utc("2016-04-05", "%F") # => 2016-04-05 00:00:00.0 +00:00
  # ```
  #
  # `Time::Location.local` will only be used as `location` if the formatted time
  # does not contain any time zone information. The return value can't be
  # assumed to be a UTC time (this can be achieved by calling `#to_local`).
  def self.parse_local(time : String, pattern : String) : Time
    parse(time, pattern, Location.local)
  end

  # Returns the number of seconds since the Unix epoch
  # (`1970-01-01 00:00:00 UTC`).
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5)
  # time.epoch # => 1452567845
  # ```
  def epoch : Int64
    (total_seconds - UNIX_SECONDS).to_i64
  end

  # Returns the number of milliseconds since the Unix epoch
  # (`1970-01-01 00:00:00 UTC`).
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5, nanosecond: 678_000_000)
  # time.epoch_ms # => 1452567845678
  # ```
  def epoch_ms : Int64
    epoch * 1_000 + (nanosecond / NANOSECONDS_PER_MILLISECOND)
  end

  # Returns the number of seconds since the Unix epoch
  # (`1970-01-01 00:00:00 UTC`) as `Float64` with nanosecond precision.
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5, nanosecond: 678_000_000)
  # time.epoch_f # => 1452567845.678
  # ```
  def epoch_f : Float64
    epoch.to_f + nanosecond.to_f / 1e9
  end

  # Returns a copy of this `Time` representing the same instant observed in
  # *location*.
  #
  # This method changes the time zone and retains the instant, which will
  # usually result in a different representation of local date-time (unless
  # both locations have the same offset).
  #
  # Ambiguous time zone transitions such as gaps and overlaps have no effect on
  # the result because it retains the same instant.
  #
  # ```
  # time_de = Time.new(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
  # time_ar = time_de.in Time::Location.load("America/Buenos_Aires")
  # time_de # => 2018-03-08 22:05:13 +01:00 Europe/Berlin
  # time_ar # => 2018-03-08 18:05:13 -03:00 America/Buenos_Aires
  # ```
  #
  # In contrast, `#to_local_in` changes to a different location while
  # preserving the same wall time, which results in different instants on the
  # time line.
  def in(location : Location) : Time
    return self if location == self.location

    Time.new(
      seconds: total_seconds,
      nanoseconds: nanosecond,
      location: location
    )
  end

  # Returns a copy of this `Time` representing the same instant in UTC
  # (`Time::Location::UTC`).
  #
  # See `#in` for details.
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

  # Returns a copy of this `Time` representing the same instant in the local
  # time zone (`Time::Location.local`).
  #
  # See `#in` for details.
  def to_local : Time
    if local?
      self
    else
      in(Location.local)
    end
  end

  private macro def_at_beginning(interval)
    # Returns a copy of this `Time` representing the beginning of the {{interval.id}}.
    def at_beginning_of_{{interval.id}} : Time
      year, month, day, day_year = year_month_day_day_year
      {{yield}}
    end
  end

  private macro def_at_end(interval)
    # Returns a copy of this `Time` representing the end of the {{interval.id}}.
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

  # Returns a copy of this `Time` representing the beginning of the minute.
  def at_beginning_of_minute : Time
    Time.new(seconds: total_seconds - second, nanoseconds: 0, location: location)
  end

  # Returns a copy of this `Time` representing the beginning of the seconds.
  #
  # This essentially scaps off `nanoseconds`.
  def at_beginning_of_second : Time
    Time.new(seconds: total_seconds, nanoseconds: 0, location: location)
  end

  # Returns a copy of this `Time` representing the beginning of the week.
  #
  # TODO: Ensure correctness in local time-line.
  def at_beginning_of_week : Time
    dow = day_of_week.value
    if dow == 0
      (self - 6.days).at_beginning_of_day
    else
      (self - (dow - 1).days).at_beginning_of_day
    end
  end

  def_at_end(year) { Time.new(year, 12, 31, 23, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns a copy of this `Time` representing the end of the semester.
  def at_end_of_semester : Time
    year, month = year_month_day_day_year
    if month <= 6
      month, day = 6, 30
    else
      month, day = 12, 31
    end
    Time.new(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing the end of the quarter.
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

  # Returns a copy of this `Time` representing the end of the week.
  #
  # TODO: Ensure correctness in local time-line.
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

  # Returns a copy of this `Time` representing the end of the minute.
  def at_end_of_minute
    Time.new(seconds: total_seconds - second + 59, nanoseconds: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing the end of the second.
  def at_end_of_second
    Time.new(seconds: total_seconds, nanoseconds: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing midday (`12:00`) of the same day.
  def at_midday : Time
    year, month, day = year_month_day_day_year
    Time.new(year, month, day, 12, 0, 0, nanosecond: 0, location: location)
  end

  {% for name in DayOfWeek.constants %}
    # Returns `true` if the day of week is {{name.id}}.
    #
    # See `#day_of_week` for details.
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
