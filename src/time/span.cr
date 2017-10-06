# `Time::Span` represents one period of time.
#
# A `Time::Span` initializes with the specified period.
# Different numbers of arguments generates a `Time::Span` in different length.
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

  def self.new(hours, minutes, seconds)
    new(0, hours, minutes, seconds)
  end

  def self.new(days, hours, minutes, seconds, nanoseconds = 0)
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

  def days
    to_i.tdiv(SECONDS_PER_DAY)
  end

  def hours
    to_i.remainder(SECONDS_PER_DAY)
        .tdiv(SECONDS_PER_HOUR)
        .to_i
  end

  def minutes
    to_i.remainder(SECONDS_PER_HOUR)
        .tdiv(SECONDS_PER_MINUTE)
        .to_i
  end

  def seconds
    to_i.remainder(SECONDS_PER_MINUTE)
        .to_i
  end

  def milliseconds
    nanoseconds / NANOSECONDS_PER_MILLISECOND
  end

  def nanoseconds
    @nanoseconds
  end

  def total_weeks
    total_days / 7
  end

  def total_days
    total_hours / 24
  end

  def total_hours
    total_minutes / 60
  end

  def total_minutes
    total_seconds / 60
  end

  def total_seconds
    to_i.to_f + (nanoseconds.to_f / NANOSECONDS_PER_SECOND)
  end

  def total_nanoseconds
    (to_i.to_f * NANOSECONDS_PER_SECOND) + nanoseconds
  end

  def to_f
    total_seconds
  end

  def to_i
    @seconds
  end

  def total_milliseconds
    total_nanoseconds / NANOSECONDS_PER_MILLISECOND
  end

  def duration
    abs
  end

  def abs
    Span.new(seconds: to_i.abs, nanoseconds: nanoseconds.abs)
  end

  def from_now
    Time.now + self
  end

  def ago
    Time.now - self
  end

  def -(other : self)
    # TODO check overflow
    Span.new(
      seconds: to_i - other.to_i,
      nanoseconds: nanoseconds - other.nanoseconds,
    )
  end

  def -
    # TODO check overflow
    Span.new(
      seconds: -to_i,
      nanoseconds: -nanoseconds,
    )
  end

  def +(other : self)
    # TODO check overflow
    Span.new(
      seconds: to_i + other.to_i,
      nanoseconds: nanoseconds + other.nanoseconds,
    )
  end

  def +
    self
  end

  def *(number : Number)
    # TODO check overflow
    Span.new(
      seconds: to_i.to_i64 * number,
      nanoseconds: nanoseconds.to_i64 * number,
    )
  end

  def /(number : Number)
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

  def /(other : self)
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

  def self.zero
    ZERO
  end

  def zero?
    to_i == 0 && nanoseconds == 0
  end
end

struct Int
  def week
    weeks
  end

  def weeks
    Time::Span.new 7 * self, 0, 0, 0
  end

  def day
    days
  end

  def days
    Time::Span.new self, 0, 0, 0
  end

  def hour
    hours
  end

  def hours
    Time::Span.new self, 0, 0
  end

  def minute
    minutes
  end

  def minutes
    Time::Span.new 0, self, 0
  end

  def second
    seconds
  end

  def seconds
    Time::Span.new 0, 0, self
  end

  def millisecond
    milliseconds
  end

  def milliseconds
    Time::Span.new 0, 0, 0, 0, (self.to_i64 * Time::NANOSECONDS_PER_MILLISECOND)
  end

  def nanosecond
    nanoseconds
  end

  def nanoseconds
    Time::Span.new(nanoseconds: self.to_i64)
  end
end

struct Float
  def days
    (self * 24).hours
  end

  def hours
    (self * 60).minutes
  end

  def minutes
    (self * 60).seconds
  end

  def seconds
    seconds = self.to_i64
    nanoseconds = (self - seconds) * Time::NANOSECONDS_PER_SECOND

    # round away from zero
    nanoseconds = (nanoseconds < 0 ? (nanoseconds - 0.5) : (nanoseconds + 0.5)).to_i64

    Time::Span.new(
      seconds: seconds,
      nanoseconds: nanoseconds,
    )
  end

  def milliseconds
    (self / 1_000).seconds
  end

  def nanoseconds
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

struct Time::MonthSpan
  getter value : Int64

  def initialize(value)
    @value = value.to_i64
  end

  def from_now
    Time.now + self
  end

  def ago
    Time.now - self
  end
end

struct Int
  def month
    months
  end

  def months
    Time::MonthSpan.new(self)
  end

  def year
    years
  end

  def years
    Time::MonthSpan.new(self * 12)
  end
end
