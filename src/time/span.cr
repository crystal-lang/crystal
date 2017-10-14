# `Time::Span` represents one period of time.
#
# A `Time::Span` initializes with the specified period.
# Different numbers of arguments generate a `Time::Span` in different length.
# Check all `#new` methods for details.
#
# ```
# Time::Span.new(nanoseconds: 10_000) # => 00:00:00.000010000
# Time::Span.new(10, 10, 10)          # => 10:10:10
# Time::Span.new(10, 10, 10, 10)      # => 10.10:10:10
# ```
#
# Calculation between `Time` also returns a `Time::Span`.
#
# ```
# span = Time.new(2015, 10, 10) - Time.new(2015, 9, 10)
# span       # => 30.00:00:00
# span.class # => Time::Span
# ```
#
# Inspection:
#
# ```
# span = Time::Span.new(20, 10, 10)
# span.hours   # => 20
# span.minutes # => 10
# span.seconds # => 10
# ```
#
# Calculation:
#
# ```
# a = Time::Span.new(20, 10, 10)
# b = Time::Span.new(10, 10, 10)
# c = a - b # => 10:00:00
# c.hours   # => 10
# ```
#
struct Time::Span
  # *Heavily* inspired by Mono's Time::Span class:
  # https://github.com/mono/mono/blob/master/mcs/class/corlib/System/Time::Span.cs

  include Comparable(self)

  MAX  = new seconds: Int64::MAX, nanoseconds: 999_999_999
  MIN  = new seconds: Int64::MIN, nanoseconds: -999_999_999
  ZERO = new nanoseconds: 0

  @seconds : Int64

  # Nanoseconds are always in the range (-999_999_999..999_999_999)
  # and always have the same sign as @seconds (if seconds is zero,
  # @nanoseconds can either be negative or positive).
  @nanoseconds : Int32

  def self.new(hours : Int, minutes : Int, seconds : Int)
    new(0, hours, minutes, seconds)
  end

  def self.new(days : Int, hours : Int, minutes : Int, seconds : Int, nanoseconds : Int = 0)
    new(
      seconds: compute_seconds!(days, hours, minutes, seconds),
      nanoseconds: nanoseconds.to_i64,
    )
  end

  def initialize(*, seconds : Int, nanoseconds : Int)
    # Normalize nanoseconds in the range 0...1_000_000_000
    seconds += nanoseconds.tdiv(NANOSECONDS_PER_SECOND)
    nanoseconds = nanoseconds.remainder(NANOSECONDS_PER_SECOND)

    # Make sure that if seconds is positive, nanoseconds is
    # positive too. Likewise, if seconds is negative, make
    # sure that nanoseconds is negative too.
    if seconds > 0 && nanoseconds < 0
      seconds -= 1
      nanoseconds += NANOSECONDS_PER_SECOND
    elsif seconds < 0 && nanoseconds > 0
      seconds += 1
      nanoseconds -= NANOSECONDS_PER_SECOND
    end

    @seconds = seconds.to_i64
    @nanoseconds = nanoseconds.to_i32
  end

  def self.new(*, nanoseconds : Int)
    new(
      seconds: nanoseconds.to_i64.tdiv(NANOSECONDS_PER_SECOND),
      nanoseconds: nanoseconds.to_i64.remainder(NANOSECONDS_PER_SECOND),
    )
  end

  private def self.compute_seconds!(days, hours, minutes, seconds)
    compute_seconds(days, hours, minutes, seconds, true).not_nil!
  end

  private def self.compute_seconds(days, hours, minutes, seconds, raise_exception)
    # there's no overflow checks for hours, minutes, ...
    # so big hours/minutes values can overflow at some point and change expected values
    hrssec = hours * 3600 # break point at (Int32::MAX - 596523)
    minsec = minutes * 60
    s = (hrssec + minsec + seconds).to_i64

    result = 0_i64

    overflow = false
    # days is problematic because it can overflow but that overflow can be
    # "legal" (i.e. temporary) (e.g. if other parameters are negative) or
    # illegal (e.g. sign change).
    if days > 0
      sd = SECONDS_PER_DAY.to_i64 * days
      if sd < days
        overflow = true
      elsif s < 0
        temp = s
        s += sd
        # positive days -> total seconds should be lower
        overflow = temp > s
      else
        s += sd
        # positive + positive != negative result
        overflow = s < 0
      end
    elsif days < 0
      sd = SECONDS_PER_DAY.to_i64 * days
      if sd > days
        overflow = true
      elsif s <= 0
        s += sd
        # negative + negative != positive result
        overflow = s > 0
      else
        nanos = s
        s += sd
        # negative days -> total nanos should be lower
        overflow = s > nanos
      end
    end

    if overflow
      if raise_exception
        raise ArgumentError.new "Time::Span too big or too small"
      end
      return nil
    end

    s
  end

  # Returns the number of full days in this time span.
  #
  # ```
  # (5.days + 25.hours).days # => 6_i64
  # ```
  def days : Int64
    to_i.tdiv(SECONDS_PER_DAY)
  end

  # Returns the number of full hours of the day (`0..23`) in this time span.
  def hours : Int32
    to_i.remainder(SECONDS_PER_DAY)
        .tdiv(SECONDS_PER_HOUR)
        .to_i
  end

  # Returns the number of full minutes of the hour (`0..59`) in this time span.
  def minutes : Int32
    to_i.remainder(SECONDS_PER_HOUR)
        .tdiv(SECONDS_PER_MINUTE)
        .to_i
  end

  # Returns the number of full seconds of the minute (`0..59`) in this time span.
  def seconds : Int32
    to_i.remainder(SECONDS_PER_MINUTE)
        .to_i
  end

  # Returns the number of milliseconds of the second (`0..999`) in this time span.
  def milliseconds : Int32
    nanoseconds / NANOSECONDS_PER_MILLISECOND
  end

  # Returns the number of nanoseconds of the second (`0..999_999_999`)
  # in this time span.
  def nanoseconds : Int32
    @nanoseconds
  end

  # Converts to a (possibly fractional) number of weeks.
  #
  # ```
  # (4.weeks + 5.days + 6.hours).total_weeks # => 4.75
  # ```
  def total_weeks : Float64
    total_days / 7
  end

  # Converts to a (possibly fractional) number of days.
  #
  # ```
  # (36.hours).total_days # => 1.5
  # ```
  def total_days : Float64
    total_hours / 24
  end

  # Converts to a (possibly fractional) number of hours.
  def total_hours : Float64
    total_minutes / 60
  end

  # Converts to a (possibly fractional) number of minutes.
  def total_minutes : Float64
    total_seconds / 60
  end

  # Converts to a (possibly fractional) number of seconds.
  def total_seconds : Float64
    to_i.to_f + (nanoseconds.to_f / NANOSECONDS_PER_SECOND)
  end

  # Converts to a number of nanoseconds.
  def total_nanoseconds : Float64
    (to_i.to_f * NANOSECONDS_PER_SECOND) + nanoseconds
  end

  # Converts to a number of milliseconds.
  def total_milliseconds : Float64
    total_nanoseconds / NANOSECONDS_PER_MILLISECOND
  end

  # Alias of `total_seconds`.
  def to_f : Float64
    total_seconds
  end

  # Returns the number of full seconds.
  def to_i : Int64
    @seconds
  end

  # Alias of `abs`.
  def duration : Time::Span
    abs
  end

  # Returns the absolute (non-negative) amount of time this `Time::Span`
  # represents by removing the sign.
  def abs : Time::Span
    Span.new(seconds: to_i.abs, nanoseconds: nanoseconds.abs)
  end

  # Returns a `Time` that happens later by `self` than the current time.
  def from_now : Time
    Time.now + self
  end

  # Returns a `Time` that happens earlier by `self` than the current time.
  def ago : Time
    Time.now - self
  end

  def -(other : self) : Time::Span
    # TODO check overflow
    Span.new(
      seconds: to_i - other.to_i,
      nanoseconds: nanoseconds - other.nanoseconds,
    )
  end

  def - : Time::Span
    # TODO check overflow
    Span.new(
      seconds: -to_i,
      nanoseconds: -nanoseconds,
    )
  end

  def +(other : self) : Time::Span
    # TODO check overflow
    Span.new(
      seconds: to_i + other.to_i,
      nanoseconds: nanoseconds + other.nanoseconds,
    )
  end

  def + : self
    self
  end

  # Returns a `Time::Span` that is *number* times longer.
  def *(number : Number) : Time::Span
    # TODO check overflow
    Span.new(
      seconds: to_i.to_i64 * number,
      nanoseconds: nanoseconds.to_i64 * number,
    )
  end

  def /(number : Number) : Time::Span
    seconds = to_i.tdiv(number)
    nanoseconds = self.nanoseconds.tdiv(number)

    remainder = to_i.remainder(number)
    nanoseconds += (remainder * NANOSECONDS_PER_SECOND) / number

    # TODO check overflow
    Span.new(
      seconds: seconds,
      nanoseconds: nanoseconds,
    )
  end

  def /(other : self) : Float64
    total_nanoseconds.to_f64 / other.total_nanoseconds.to_f64
  end

  def <=>(other : self)
    cmp = to_i <=> other.to_i
    cmp = nanoseconds <=> other.nanoseconds if cmp == 0
    cmp
  end

  def inspect(io : IO)
    if to_i < 0 || nanoseconds < 0
      io << '-'
    end

    # We need to take absolute values of all components.
    # Can't handle negative timespans by negating the Time::Span
    # as a whole. This would lead to an overflow for the
    # degenerate case `Time::Span.MinValue`.
    if days != 0
      io << days.abs
      io << '.'
    end

    hours = self.hours.abs
    io << '0' if hours < 10
    io << hours

    io << ':'

    minutes = self.minutes.abs
    io << '0' if minutes < 10
    io << minutes

    io << ':'

    seconds = self.seconds.abs
    io << '0' if seconds < 10
    io << seconds

    nanoseconds = self.nanoseconds.abs
    if nanoseconds != 0
      io << '.'
      io << '0' if nanoseconds < 100000000
      io << '0' if nanoseconds < 10000000
      io << '0' if nanoseconds < 1000000
      io << '0' if nanoseconds < 100000
      io << '0' if nanoseconds < 10000
      io << '0' if nanoseconds < 1000
      io << '0' if nanoseconds < 100
      io << '0' if nanoseconds < 10
      io << nanoseconds
    end
  end

  def self.zero : Time::Span
    ZERO
  end

  def zero? : Bool
    to_i == 0 && nanoseconds == 0
  end
end

struct Int
  # :nodoc:
  def week : Time::Span
    weeks
  end

  # Returns a `Time::Span` of `self` weeks.
  def weeks : Time::Span
    Time::Span.new 7 * self, 0, 0, 0
  end

  # :nodoc:
  def day : Time::Span
    days
  end

  # Returns a `Time::Span` of `self` days.
  def days : Time::Span
    Time::Span.new self, 0, 0, 0
  end

  # :nodoc:
  def hour : Time::Span
    hours
  end

  # Returns a `Time::Span` of `self` hours.
  def hours : Time::Span
    Time::Span.new self, 0, 0
  end

  # :nodoc:
  def minute : Time::Span
    minutes
  end

  # Returns a `Time::Span` of `self` minutes.
  def minutes : Time::Span
    Time::Span.new 0, self, 0
  end

  # :nodoc:
  def second : Time::Span
    seconds
  end

  # Returns a `Time::Span` of `self` seconds.
  def seconds : Time::Span
    Time::Span.new 0, 0, self
  end

  # :nodoc:
  def millisecond : Time::Span
    milliseconds
  end

  # Returns a `Time::Span` of `self` milliseconds.
  def milliseconds : Time::Span
    Time::Span.new 0, 0, 0, 0, (self.to_i64 * Time::NANOSECONDS_PER_MILLISECOND)
  end

  # :nodoc:
  def nanosecond : Time::Span
    nanoseconds
  end

  # Returns a `Time::Span` of `self` nanoseconds.
  def nanoseconds : Time::Span
    Time::Span.new(nanoseconds: self.to_i64)
  end
end

struct Float
  # Returns a `Time::Span` of `self` days.
  def days : Time::Span
    (self * 24).hours
  end

  # Returns a `Time::Span` of `self` hours.
  def hours : Time::Span
    (self * 60).minutes
  end

  # Returns a `Time::Span` of `self` minutes.
  def minutes : Time::Span
    (self * 60).seconds
  end

  # Returns a `Time::Span` of `self` seconds.
  def seconds : Time::Span
    seconds = self.to_i64
    nanoseconds = (self - seconds) * Time::NANOSECONDS_PER_SECOND

    # round away from zero
    nanoseconds = (nanoseconds < 0 ? (nanoseconds - 0.5) : (nanoseconds + 0.5)).to_i64

    Time::Span.new(
      seconds: seconds,
      nanoseconds: nanoseconds,
    )
  end

  # Returns a `Time::Span` of `self` milliseconds.
  def milliseconds : Time::Span
    (self / 1_000).seconds
  end

  # Returns a `Time::Span` of `self` nanoseconds.
  def nanoseconds : Time::Span
    seconds = (self / Time::NANOSECONDS_PER_SECOND).to_i64
    nanoseconds = self.remainder(Time::NANOSECONDS_PER_SECOND)

    # round away from zero
    nanoseconds = (nanoseconds < 0 ? (nanoseconds - 0.5) : (nanoseconds + 0.5)).to_i64

    Time::Span.new(
      seconds: seconds,
      nanoseconds: nanoseconds,
    )
  end
end

# Represents a number of months passed. Used for shifting `Time`s by a
# specified number of months.
#
# ```
# Time.new(2016, 2, 1) + 13.months # => 2017-03-01 00:00:00
# Time.new(2016, 2, 29) + 2.years  # => 2018-02-28 00:00:00
# ```
struct Time::MonthSpan
  # The number of months.
  getter value : Int64

  def initialize(value : Int)
    @value = value.to_i64
  end

  # Returns a `Time` that happens N months after now.
  def from_now : Time
    Time.now + self
  end

  # Returns a `Time` that happens N months before now.
  def ago : Time
    Time.now - self
  end
end

struct Int
  # :nodoc:
  def month : Time::MonthSpan
    months
  end

  # Returns a `Time::MonthSpan` of `self` months.
  def months : Time::MonthSpan
    Time::MonthSpan.new(self)
  end

  # :nodoc:
  def year : Time::MonthSpan
    years
  end

  # Returns a `Time::MonthSpan` of `self` years.
  def years : Time::MonthSpan
    Time::MonthSpan.new(self * 12)
  end
end
