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
# ```
# Time.utc                                        # returns the current time in UTC
# Time.local Time::Location.load("Europe/Berlin") # returns the current time in time zone Europe/Berlin
# Time.local                                      # returns the current time in current time zone
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
# time.to_s # => "2016-02-15 10:20:30 UTC"
# time = Time.local(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))
# time.to_s # => "2016-02-15 10:20:30 +01:00"
# # The time-of-day can be omitted and defaults to midnight (start of day):
# time = Time.utc(2016, 2, 15)
# time.to_s # => "2016-02-15 00:00:00 UTC"
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
# For querying if a time is at a specific day of week, `Time` offers named
# predicate methods, delegating to `#day_of_week`:
#
# ```
# time.monday? # => true
# # ...
# time.sunday? # => false
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
# time = Time.local(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
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
# time_de = Time.local(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
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
# Similarly, `Time.parse` and `Time.parse!` are used to construct a `Time` instance from date-time
# information in a string, according to a specified pattern:
#
# ```
# Time.parse("2015-10-12 10:30:00 +00:00", "%Y-%m-%d %H:%M:%S %z", Time::Location::UTC)
# Time.parse!("2015-10-12 10:30:00 +00:00", "%Y-%m-%d %H:%M:%S %z")
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
# When `Time.local` is called multiple times, the difference between the
# returned instances is not guaranteed to equal to the time elapsed between
# making the calls; even the order of the returned `Time` instances might
# not reflect invocation order.
#
# ```
# t1 = Time.utc
# # operation that takes 1 minute
# t2 = Time.utc
# t2 - t1 # => ?
# ```
#
# The resulting `Time::Span` could be anything, even negative, if the
# computer's wall clock has changed between both calls.
#
# As an alternative, the operating system also provides a monotonic clock.
# Its time-line has no specified starting point but is strictly linearly
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
  include Steppable

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

  # This constant is defined to be "1970-01-01 00:00:00 UTC".
  # Can be used to create a `Time::Span` that represents an Unix Epoch time duration.
  #
  # ```
  # Time.utc - Time::UNIX_EPOCH
  # ```
  UNIX_EPOCH = new(unsafe_utc_seconds: 62135596800)

  # :nodoc:
  MAX_SECONDS = 315537897599_i64

  # `DayOfWeek` represents a day of the week in the Gregorian calendar.
  #
  # ```
  # time = Time.local(2016, 2, 15)
  # time.day_of_week # => Time::DayOfWeek::Monday
  # ```
  #
  # Each member is identified by its ordinal number starting from `Monday = 1`
  # according to [ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf).
  #
  # `#value` returns this ordinal number. It can easily be converted to the also
  # common numbering based on `Sunday = 0` using `value % 7`.
  enum DayOfWeek
    Monday    = 1
    Tuesday   = 2
    Wednesday = 3
    Thursday  = 4
    Friday    = 5
    Saturday  = 6
    Sunday    = 7

    # Returns the day of week that has the given value, or raises if no such member exists.
    #
    # This method also accepts `0` to identify `Sunday` in order to be compliant
    # with the `Sunday = 0` numbering. All other days are equal in both formats.
    def self.from_value(value : Int32) : self
      value = 7 if value == 0
      super(value)
    end
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
  def self.local(location : Location = Location.local) : Time
    seconds, nanoseconds = Crystal::System::Time.compute_utc_seconds_and_nanoseconds
    new(seconds: seconds, nanoseconds: nanoseconds, location: location)
  end

  # Creates a new `Time` instance representing the current time from the
  # system clock in UTC.
  def self.utc : Time
    local(Location::UTC)
  end

  # Creates a new `Time` instance representing the given local date-time in
  # *location* (defaults to local time zone).
  #
  # ```
  # time = Time.local(2016, 2, 15, 10, 20, 30, location: Time::Location.load("Europe/Berlin"))
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
  # time = Time.utc(2016, 2, 15)
  # time.to_s # => "2016-02-15 00:00:00 UTC"
  # ```
  #
  # The local date-time representation is resolved to a single instant based on
  # the offset observed in the *location* at this time.
  #
  # This process can sometimes be ambiguous, mostly due skipping or repeating
  # times at time zone transitions. For example, in `America/New_York` the
  # date-time `2011-03-13 02:15:00` never occurred, there is a gap between time
  # zones. In return, `2011-11-06 01:15:00` occurred twice because of overlapping
  # time zones.
  #
  # In such cases, the choice of time zone, and therefore the time, is not
  # well-defined. This method returns a time that is correct in one of the two
  # zones involved in the transition, but it does not guarantee which.
  def self.local(year : Int32, month : Int32, day : Int32, hour : Int32 = 0, minute : Int32 = 0, second : Int32 = 0, *, nanosecond : Int32 = 0, location : Location = Location.local) : Time
    unless 1 <= year <= 9999 &&
           1 <= month <= 12 &&
           1 <= day <= Time.days_in_month(year, month) &&
           (
             0 <= hour <= 23 ||
             (hour == 24 && minute == 0 && second == 0 && nanosecond == 0)
           ) &&
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
    seconds = seconds - zone_offset_at(seconds, location) if !location.utc?

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
    local(year, month, day, hour, minute, second, nanosecond: nanosecond, location: Location::UTC)
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

  # :nodoc:
  protected def initialize(*, unsafe_utc_seconds : Int64)
    @seconds = unsafe_utc_seconds
    @nanoseconds = 0
    @location = Location::UTC
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
      seconds = UNIX_EPOCH.total_seconds + time.tv_sec
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
  # Time.unix(981173106) # => 2001-02-03 04:05:06 UTC
  # ```
  def self.unix(seconds : Int) : Time
    utc(seconds: UNIX_EPOCH.total_seconds + seconds, nanoseconds: 0)
  end

  # Creates a new `Time` instance that corresponds to the number of
  # *milliseconds* elapsed since the Unix epoch (`1970-01-01 00:00:00 UTC`).
  #
  # The time zone is always UTC.
  #
  # ```
  # time = Time.unix_ms(981173106789) # => 2001-02-03 04:05:06.789 UTC
  # time.millisecond                  # => 789
  # ```
  def self.unix_ms(milliseconds : Int) : Time
    milliseconds = milliseconds.to_i64
    seconds = UNIX_EPOCH.total_seconds + (milliseconds // 1_000)
    nanoseconds = (milliseconds % 1000) * NANOSECONDS_PER_MILLISECOND
    utc(seconds: seconds, nanoseconds: nanoseconds.to_i)
  end

  # Creates a new `Time` instance that corresponds to the number of
  # *nanoseconds* elapsed since the Unix epoch (`1970-01-01 00:00:00.000000000 UTC`).
  #
  # The time zone is always UTC.
  #
  # ```
  # time = Time.unix_ns(981173106789479273) # => 2001-02-03 04:05:06.789479273 UTC
  # time.nanosecond                         # => 789479273
  # ```
  def self.unix_ns(nanoseconds : Int) : Time
    seconds = UNIX_EPOCH.total_seconds + (nanoseconds // 1_000_000_000)
    nanoseconds = nanoseconds % 1_000_000_000
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
  # tokyo.inspect    # => "2019-01-01 00:00:00.0 +09:00 Asia/Tokyo"
  # new_york.inspect # => "2019-01-01 00:00:00.0 -05:00 America/New_York"
  # ```
  def to_local_in(location : Location) : Time
    local_seconds = offset_seconds
    local_seconds -= Time.zone_offset_at(local_seconds, location)

    Time.new(seconds: local_seconds, nanoseconds: nanosecond, location: location)
  end

  def clone : Time
    self
  end

  # Returns a copy of this `Time` with *span* added.
  #
  # See `#shift` for details.
  def +(span : Time::Span) : Time
    shift span.to_i, span.nanoseconds
  end

  # Returns a copy of this `Time` with *span* subtracted.
  #
  # See `#shift` for details.
  def -(span : Time::Span) : Time
    shift -span.to_i, -span.nanoseconds
  end

  # Returns a copy of this `Time` with *span* added.
  #
  # It adds the number of months with overflow increasing the year.
  # If the resulting day-of-month would be invalid, it is adjusted to the last
  # valid day of the month.
  #
  # For example, adding `1.month` to `2007-03-31` would result in the invalid
  # date `2007-04-31` which will be adjusted to `2007-04-30`.
  #
  # This operates on the local time-line, such that the local date-time
  # representations of month and year are increased by the specified amount.
  #
  # If the resulting date-time is ambiguous due to time zone transitions,
  # a correct time will be returned, but it does not guarantee which.
  def +(span : Time::MonthSpan) : Time
    shift months: span.value.to_i
  end

  # Returns a copy of this `Time` with *span* subtracted.
  #
  # It adds the number of months with overflow decreasing the year.
  # If the resulting day-of-month would be invalid, it is adjusted to the last
  # valid day of the month.
  #
  # For example, subtracting `1.month` from `2007-05-31` would result in the invalid
  # date `2007-04-31` which will be adjusted to `2007-04-30`.
  #
  # This operates on the local time-line, such that the local date-time
  # representations of month and year are decreased by the specified amount.
  #
  # If the resulting date-time is ambiguous due to time zone transitions,
  # a correct time will be returned, but it does not guarantee which.
  def -(span : Time::MonthSpan) : Time
    shift months: -span.value.to_i
  end

  # Returns a copy of this `Time` shifted by the number of *seconds* and
  # *nanoseconds*.
  #
  # Positive values result in a later time, negative values in an earlier time.
  #
  # This operates on the instant time-line, such that adding the equivalent of
  # one hour will always be a duration of one hour later.
  # The local date-time representation may change by a different amount,
  # depending on time zone transitions.
  #
  # Overflow in *nanoseconds* will be transferred to *seconds*.
  #
  # There is no explicit limit on the input values but the addition must result
  # in a valid time between `0001-01-01 00:00:00.0` and
  # `9999-12-31 23:59:59.999_999_999`. Otherwise `ArgumentError` is raised.
  def shift(seconds : Int, nanoseconds : Int) : Time
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

  # Returns a copy of this `Time` shifted by the amount of calendaric units
  # provided as arguments.
  #
  # Positive values result in a later time, negative values in an earlier time.
  #
  # This operates on the local time-line, such that the local date-time
  # representation of the result will be apart by the specified amounts, but the
  # elapsed time between both instances might not equal to the combined default
  # duration.
  # This is the case for example when adding a day over a daylight-savings time
  # change:
  #
  # ```
  # start = Time.local(2017, 10, 28, 13, 37, location: Time::Location.load("Europe/Berlin"))
  # one_day_later = start.shift days: 1
  #
  # one_day_later - start # => 25.hours
  # ```
  #
  # *years* is equivalent to `12` months and *weeks* is equivalent to `7` days.
  #
  # If the day-of-month resulting from shifting by *years* and *months* would be
  # invalid, the date is adjusted to the last valid day of the month.
  # For example, adding one month to `2018-08-31` would result in the invalid
  # date `2018-09-31` which will be adjusted to `2018-09-30`:
  # ```
  # Time.utc(2018, 7, 31).shift(months: 1) # => Time.utc(2018, 8, 31)
  # Time.utc(2018, 8, 31).shift(months: 1) # => Time.utc(2018, 9, 30)
  # ```
  #
  # Overflow in smaller units is transferred to the next larger unit.
  #
  # Changes are applied in the same order as the arguments, sorted by increasing
  # granularity. This is relevant because the order of operations can change the result:
  #
  # ```
  # Time.utc(2018, 8, 31).shift(months: 1, days: -1)       # => Time.utc(2018, 9, 29)
  # Time.utc(2018, 8, 31).shift(months: 1).shift(days: -1) # => Time.utc(2018, 9, 29)
  # Time.utc(2018, 8, 31).shift(days: -1).shift(months: 1) # => Time.utc(2018, 9, 30)
  # ```
  #
  # There is no explicit limit on the input values but the shift must result
  # in a valid time between `0001-01-01 00:00:00.0` and
  # `9999-12-31 23:59:59.999_999_999`. Otherwise `ArgumentError` is raised.
  #
  # If the resulting date-time is ambiguous due to time zone transitions,
  # a correct time will be returned, but it does not guarantee which.
  def shift(*, years : Int = 0, months : Int = 0, weeks : Int = 0, days : Int = 0,
            hours : Int = 0, minutes : Int = 0, seconds : Int = 0, nanoseconds : Int = 0)
    seconds = seconds.to_i64

    # Skip the entire month-based calculations if year and month are zero
    if years.zero? && months.zero?
      # Using offset_seconds with applied zone offset so that calculations
      # are applied to the equivalent UTC representation of this local time.
      seconds += offset_seconds
    else
      year, month, day, _ = year_month_day_day_year

      year += years

      months += month
      year += months.tdiv(12)
      month = months.remainder(12)

      if month < 1
        month = 12 + month
        year -= 1
      end

      maxday = Time.days_in_month(year, month)
      if day > maxday
        day = maxday
      end

      seconds += Time.absolute_days(year, month, day).to_i64 * SECONDS_PER_DAY
      seconds += offset_seconds % SECONDS_PER_DAY
    end

    # FIXME: These operations currently don't have overflow checks applied.
    # This should be fixed when operators by default raise on overflow.
    seconds += weeks * SECONDS_PER_WEEK
    seconds += days * SECONDS_PER_DAY
    seconds += hours * SECONDS_PER_HOUR
    seconds += minutes * SECONDS_PER_MINUTE

    # Apply the nanosecond shift (including overflow handling) and transform to
    # local time zone in `location`:
    Time.utc(seconds: seconds, nanoseconds: self.nanosecond).shift(0, nanoseconds).to_local_in(location)
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

  # Returns a `Tuple` with `year`, `month` and `day`.
  def date : Tuple(Int32, Int32, Int32)
    year, month, day, _ = year_month_day_day_year
    {year, month, day}
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
    ((offset_seconds % SECONDS_PER_DAY) // SECONDS_PER_HOUR).to_i
  end

  # Returns the minute of the hour (`0..59`).
  def minute : Int32
    ((offset_seconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE).to_i
  end

  # Returns the second of the minute (`0..59`).
  def second : Int32
    (offset_seconds % SECONDS_PER_MINUTE).to_i
  end

  # Returns the millisecond of the second (`0..999`).
  def millisecond : Int32
    nanosecond // NANOSECONDS_PER_MILLISECOND
  end

  # Returns the nanosecond of the second (`0..999_999_999`).
  def nanosecond : Int32
    @nanoseconds
  end

  # Returns the ISO calendar year and week in which this instance occurs.
  #
  # The ISO calendar year to which the week belongs is not always in the same
  # as the year of the regular calendar date. The first three days of January
  # sometimes belong to week 52 (or 53) of the previous year;
  # equally the last three days of December sometimes are already in week 1
  # of the following year.
  #
  # For that reason, this method returns a tuple `year, week` consisting of the
  # calendar year to which the calendar week belongs and the ordinal number of
  # the week within that year.
  #
  # Together with `#day_of_week` this represents a specific day as commercial or
  # week date format `year, week, day_of_week` in the same way as the typical
  # format `year, month, day`.
  # `.week_date` creates a `Time` instance from a week date.
  def calendar_week : {Int32, Int32}
    year, month, day, day_year = year_month_day_day_year

    day_of_week = self.day_of_week

    # The week number can be calculated as number of Mondays in the year up to
    # the ordinal date.
    # The addition by +10 consists of +7 to start the week numbering with 1
    # instead of 0 and +3 because the first week has already started in the
    # previous year and the first Monday is actually in week 2.
    week_number = (day_year - day_of_week.to_i + 10) // 7

    if week_number == 0
      # Week number 0 means the date belongs to the last week of the previous year.
      year -= 1

      # The week number depends on whether the previous year has 52 or 53 weeks
      # which can be determined by the day of week of January 1.
      # The year has 53 weeks if January 1 is on a Friday or the year was a leap
      # year and January 1 is on a Saturday.
      jan1_day_of_week = DayOfWeek.from_value((day_of_week.to_i - day_year + 1) % 7)

      if jan1_day_of_week == DayOfWeek::Friday || (jan1_day_of_week == DayOfWeek::Saturday && Time.leap_year?(year))
        week_number = 53
      else
        week_number = 52
      end
    elsif week_number == 53
      # Week number 53 is actually week number 1 of the following year, if
      # December 31 is on a Monday, Tuesday or Wednesday.
      dec31_day_of_week = (day_of_week.to_i + 31 - day) % 7

      if dec31_day_of_week <= DayOfWeek::Wednesday.to_i
        year += 1
        week_number = 1
      end
    end

    {year, week_number}
  end

  # Creates an instance specified by a commercial week date consisting of ISO
  # calendar *year*, *week* and a *day_of_week*.
  #
  # This equates to the results from `#calendar_week` and `#day_of_week`.
  #
  # Valid value ranges for the individual fields:
  #
  # * `year`: `1..9999`
  # * `week`: `1..53`
  # * `day_of_week`: `1..7`
  def self.week_date(year : Int32, week : Int32, day_of_week : Int32 | DayOfWeek, hour : Int32 = 0, minute : Int32 = 0, second : Int32 = 0, *, nanosecond : Int32 = 0, location : Location = Location.local) : self
    # For this calculation we need to know the weekday of January 4.
    # The number of the day plus a fixed offset of 4 gives a correction value
    # for this year.
    jan4_day_of_week = Time.utc(year, 1, 4).day_of_week
    correction = jan4_day_of_week.to_i + 4

    # The number of weeks multiplied by 7 plus the day of week and the calculated
    # correction value results in the ordinal day of the year.
    ordinal = week * 7 + day_of_week.to_i - correction

    # Adjust the year if the year of the week date does not correspond with the calendar year around New Years.

    if ordinal < 1
      # If the ordinal day is zero or negative, the date belongs to the previous
      # calendar year.
      year -= 1
      ordinal += Time.days_in_year(year)
    elsif ordinal > (days_in_year = Time.days_in_year(year))
      # If the ordinal day is greater than the number of days in the year, the date
      # belongs to the next year.
      ordinal -= days_in_year
      year += 1
    end

    # The ordinal day together with the year fully specifies the date.
    # A new instance for January 1 plus the ordinal days results in the correct date.
    # This calculation needs to be in UTC to avoid issues with changes in
    # the time zone offset (such as daylight savings time).
    # TODO: Use #shift or #to_local_in instead
    time = Time.utc(year, 1, 1, hour, minute, second, nanosecond: nanosecond) + ordinal.days

    # If the location is UTC, we're done
    return time if location.utc?

    # otherwise, transfer to the specified location without changing the time of day.
    time = time.in(location: location)
    time - time.offset.seconds
  end

  # Returns the duration between this `Time` and midnight of the same day.
  #
  # This is equivalent to creating a `Time::Span` from the time-of-day fields:
  #
  # ```
  # time.time_of_day == Time::Span.new(hours: time.hour, minutes: time.minute, seconds: time.second, nanoseconds: time.nanosecond)
  # ```
  def time_of_day : Time::Span
    Span.new(nanoseconds: NANOSECONDS_PER_SECOND * (offset_seconds % SECONDS_PER_DAY) + nanosecond)
  end

  # Returns the day of the week (`Monday..Sunday`).
  def day_of_week : Time::DayOfWeek
    days = offset_seconds // SECONDS_PER_DAY
    DayOfWeek.new days.to_i % 7 + 1
  end

  # Returns the day of the year.
  #
  # The value range is `1..365` in normal years and `1..366` in leap years.
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
  # Since the system's settings may change during a program's runtime,
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
  # need to be transformed to the same time zone.
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
  # time_de = Time.local(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
  # time_ar = Time.local(2018, 3, 8, 18, 5, 13, location: Time::Location.load("America/Buenos_Aires"))
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
  def inspect(io : IO, with_nanoseconds = true) : Nil
    to_s io, "%F %T"

    if with_nanoseconds
      if @nanoseconds == 0
        io << ".0"
      else
        to_s io, ".%N"
      end
    end

    if utc?
      io << " UTC"
    else
      io << ' '
      zone.format(io)
      io << ' ' << location.name unless location.fixed?
    end
  end

  # Prints this `Time` to *io*.
  #
  # The local date-time is formatted as date string `YYYY-MM-DD HH:mm:ss +ZZ:ZZ:ZZ`.
  # Nanoseconds are always omitted.
  # When the location is `UTC`, the offset is replaced with the string `UTC`.
  # Offset seconds are omitted if `0`.
  def to_s(io : IO) : Nil
    to_s(io, "%F %T ")

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
  # time = Time.local(2016, 4, 5)
  # time.to_s("%F") # => "2016-04-05"
  # ```
  def to_s(format : String) : String
    Format.new(format).format(self)
  end

  # Formats this `Time` according to the pattern in *format* to the given *io*.
  #
  # See `Time::Format` for details.
  def to_s(io : IO, format : String) : Nil
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
  #
  # Number of seconds decimals can be selected with *fraction_digits*.
  # Values accepted are 0 (the default, no decimals), 3 (milliseconds), 6 (microseconds) or 9 (nanoseconds).
  def to_rfc3339(*, fraction_digits : Int = 0)
    Format::RFC_3339.format(to_utc, fraction_digits)
  end

  # Format this time using the format specified by [RFC 3339](https://tools.ietf.org/html/rfc3339) ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  # into the given *io*.
  #
  #
  # Number of seconds decimals can be selected with *fraction_digits*.
  # Values accepted are 0 (the default, no decimals), 3 (milliseconds), 6 (microseconds) or 9 (nanoseconds).
  def to_rfc3339(io : IO, *, fraction_digits : Int = 0) : Nil
    Format::RFC_3339.format(to_utc, io, fraction_digits)
  end

  # Parse time format specified by [RFC 3339](https://tools.ietf.org/html/rfc3339) ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  #
  # ```
  # Time.parse_rfc3339("2016-02-15T04:35:50Z") # => 2016-02-15 04:35:50.0 UTC
  # ```
  def self.parse_rfc3339(time : String) : self
    Format::RFC_3339.parse(time)
  end

  # Parse datetime format specified by [ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf).
  #
  # This is similar to `.parse_rfc3339` but RFC 3339 defines a more strict format.
  # In ISO 8601 for examples, field delimiters (`-`, `:`) are optional.
  #
  # Use `#to_rfc3339` to format a `Time` according to .
  #
  # ```
  # Time.parse_iso8601("2016-02-15T04:35:50Z") # => 2016-02-15 04:35:50.0 UTC
  # ```
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
  def to_rfc2822 : String
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
  #
  # ```
  # Time.parse_rfc2822("Mon, 15 Feb 2016 04:35:50 UTC") # => 2016-02-15 04:35:50.0 UTC
  # ```
  def self.parse_rfc2822(time : String) : self
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
  # `Time::Location.local` as default location
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
  # time.to_unix # => 1452567845
  # ```
  def to_unix : Int64
    (total_seconds - UNIX_EPOCH.total_seconds).to_i64
  end

  # Returns the number of milliseconds since the Unix epoch
  # (`1970-01-01 00:00:00 UTC`).
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5, nanosecond: 678_000_000)
  # time.to_unix_ms # => 1452567845678
  # ```
  def to_unix_ms : Int64
    to_unix * 1_000 + (nanosecond // NANOSECONDS_PER_MILLISECOND)
  end

  # Returns the number of nanoseconds since the Unix epoch
  # (`1970-01-01 00:00:00.000000000 UTC`).
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5, nanosecond: 678_910_123)
  # time.to_unix_ns # => 1452567845678910123
  # ```
  def to_unix_ns : Int128
    (to_unix.to_i128 * NANOSECONDS_PER_SECOND) + nanosecond
  end

  # Returns the number of seconds since the Unix epoch
  # (`1970-01-01 00:00:00 UTC`) as `Float64` with nanosecond precision.
  #
  # ```
  # time = Time.utc(2016, 1, 12, 3, 4, 5, nanosecond: 678_000_000)
  # time.to_unix_f # => 1452567845.678
  # ```
  def to_unix_f : Float64
    to_unix.to_f + nanosecond.to_f / 1e9
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
  # time_de = Time.local(2018, 3, 8, 22, 5, 13, location: Time::Location.load("Europe/Berlin"))
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
      self.in(Location.local)
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

  def_at_beginning(year) { Time.local(year, 1, 1, location: location) }
  def_at_beginning(semester) { Time.local(year, ((month - 1) // 6) * 6 + 1, 1, location: location) }
  def_at_beginning(quarter) { Time.local(year, ((month - 1) // 3) * 3 + 1, 1, location: location) }
  def_at_beginning(month) { Time.local(year, month, 1, location: location) }
  def_at_beginning(day) { Time.local(year, month, day, location: location) }
  def_at_beginning(hour) { Time.local(year, month, day, hour, location: location) }

  # Returns a copy of this `Time` representing the beginning of the minute.
  def at_beginning_of_minute : Time
    Time.new(seconds: total_seconds - second, nanoseconds: 0, location: location)
  end

  # Returns a copy of this `Time` representing the beginning of the seconds.
  #
  # This essentially resets `nanoseconds` to 0.
  def at_beginning_of_second : Time
    Time.new(seconds: total_seconds, nanoseconds: 0, location: location)
  end

  # Returns a copy of this `Time` representing the beginning of the week.
  #
  # The week starts on Monday by default, but can be configured by passing a different `start_day` as a `Time::DayOfWeek`.
  #
  # ```
  # now = Time.utc(2023, 5, 16, 17, 53, 22)
  # now.at_beginning_of_week             # => 2023-05-15 00:00:00 UTC
  # now.at_beginning_of_week(:sunday)    # => 2023-05-14 00:00:00 UTC
  # now.at_beginning_of_week(:wednesday) # => 2023-05-10 00:00:00 UTC
  # ```
  # TODO: Ensure correctness in local time-line.
  def at_beginning_of_week(start_day : Time::DayOfWeek = :monday) : Time
    (self - ((day_of_week.value - start_day.value) % 7).days).at_beginning_of_day
  end

  def_at_end(year) { Time.local(year, 12, 31, 23, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns a copy of this `Time` representing the end of the semester.
  def at_end_of_semester : Time
    year, month, _, _ = year_month_day_day_year
    if month <= 6
      month, day = 6, 30
    else
      month, day = 12, 31
    end
    Time.local(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing the end of the quarter.
  def at_end_of_quarter : Time
    year, month, _, _ = year_month_day_day_year
    if month <= 3
      month, day = 3, 31
    elsif month <= 6
      month, day = 6, 30
    elsif month <= 9
      month, day = 9, 30
    else
      month, day = 12, 31
    end
    Time.local(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location)
  end

  def_at_end(month) { Time.local(year, month, Time.days_in_month(year, month), 23, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns a copy of this `Time` representing the end of the week.
  #
  # TODO: Ensure correctness in local time-line.
  def at_end_of_week : Time
    (self + (7 - day_of_week.value).days).at_end_of_day
  end

  def_at_end(day) { Time.local(year, month, day, 23, 59, 59, nanosecond: 999_999_999, location: location) }
  def_at_end(hour) { Time.local(year, month, day, hour, 59, 59, nanosecond: 999_999_999, location: location) }

  # Returns a copy of this `Time` representing the end of the minute.
  def at_end_of_minute : Time
    Time.new(seconds: total_seconds - second + 59, nanoseconds: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing the end of the second.
  def at_end_of_second : Time
    Time.new(seconds: total_seconds, nanoseconds: 999_999_999, location: location)
  end

  # Returns a copy of this `Time` representing midday (`12:00`) of the same day.
  def at_midday : Time
    year, month, day, _ = year_month_day_day_year
    Time.local(year, month, day, 12, 0, 0, nanosecond: 0, location: location)
  end

  {% for name in DayOfWeek.constants %}
    # Returns `true` if the day of week is {{name.id}}.
    #
    # See `#day_of_week` for details.
    def {{name.id.downcase}}? : Bool
      day_of_week.{{name.id.downcase}}?
    end
  {% end %}

  # Returns the number of days from `0001-01-01` to the date indicated
  # by *year*, *month*, *day* in the proleptic Gregorian calendar.
  #
  # The valid range for *year* is `1..9999` and for *month* `1..12`. The value
  # of *day*  is not validated and can exceed the number of days in the specified
  # month or even a year.
  protected def self.absolute_days(year, month, day) : Int32
    days_per_month = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH

    days_in_year = day - 1
    month_index = 1
    while month_index < month
      days_in_year += days_per_month[month_index]
      month_index += 1
    end

    year -= 1

    year * 365 + year // 4 - year // 100 + year // 400 + days_in_year
  end

  protected def total_seconds
    @seconds
  end

  protected def offset_seconds
    @seconds + offset
  end

  # Returns the calendaric representation of this instance's date.
  #
  # The return value is a tuple consisting of year (`1..9999`), month (`1..12`),
  # day (`1..31`) and ordinal day of the year (`1..366`).
  protected def year_month_day_day_year : {Int32, Int32, Int32, Int32}
    total_days = (offset_seconds // SECONDS_PER_DAY).to_i

    num400 = total_days // DAYS_PER_400_YEARS
    total_days -= num400 * DAYS_PER_400_YEARS

    num100 = total_days // DAYS_PER_100_YEARS
    if num100 == 4 # leap
      num100 = 3
    end
    total_days -= num100 * DAYS_PER_100_YEARS

    num4 = total_days // DAYS_PER_4_YEARS
    total_days -= num4 * DAYS_PER_4_YEARS

    numyears = total_days // 365
    if numyears == 4 # leap
      numyears = 3
    end
    total_days -= numyears * 365

    year = num400 * 400 + num100 * 100 + num4 * 4 + numyears + 1

    ordinal_day_in_year = total_days + 1

    if (numyears == 3) && ((num100 == 3) || !(num4 == 24)) # 31 dec leap year
      days_per_month = DAYS_MONTH_LEAP
    else
      days_per_month = DAYS_MONTH
    end

    month = 1
    while true
      days_in_month = days_per_month[month]
      break if total_days < days_in_month

      total_days -= days_in_month
      month += 1
    end

    day = total_days + 1

    {year, month, day, ordinal_day_in_year}
  end

  protected def self.zone_offset_at(seconds, location)
    unix = seconds - UNIX_EPOCH.total_seconds
    zone, range = location.lookup_with_boundaries(unix)

    if zone.offset != 0
      case unix - zone.offset
      when .<(range[0])
        zone = location.lookup(range[0] - 1)
      when .>=(range[1])
        zone = location.lookup(range[1])
      else
        # in range
      end
    end

    zone.offset
  end
end

require "./time/**"
