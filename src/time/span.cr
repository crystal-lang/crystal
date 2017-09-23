# `Time::Span` represents one period of time.
#
# A `Time::Span` initializes with the specified period.
# Different numbers of arguments generates a `Time::Span` in different length.
# Check all `#new` methods for details.
#
# ```
# Time::Span.new(10000)          # => 00:00:00.001
# Time::Span.new(10, 10, 10)     # => 10:10:10
# Time::Span.new(10, 10, 10, 10) # => 10.10:10:10
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

  TicksPerMicrosecond = 10_i64
  TicksPerMillisecond = TicksPerMicrosecond * 1000
  TicksPerSecond      = TicksPerMillisecond * 1000
  TicksPerMinute      = TicksPerSecond * 60
  TicksPerHour        = TicksPerMinute * 60
  TicksPerDay         = TicksPerHour * 24

  MaxValue = new Int64::MAX
  MinValue = new Int64::MIN
  Zero     = new 0

  # 1 tick is a tenth of a microsecond
  @ticks : Int64

  getter ticks

  def initialize(ticks)
    @ticks = ticks.to_i64
  end

  def initialize(hours, minutes, seconds)
    @ticks = calculate_ticks! 0, hours, minutes, seconds, 0
  end

  def initialize(days, hours, minutes, seconds)
    @ticks = calculate_ticks! days, hours, minutes, seconds, 0
  end

  def initialize(days, hours, minutes, seconds, milliseconds)
    @ticks = calculate_ticks! days, hours, minutes, seconds, milliseconds
  end

  private def calculate_ticks!(days, hours, minutes, seconds, milliseconds)
    calculate_ticks(days, hours, minutes, seconds, milliseconds, true).not_nil!
  end

  private def calculate_ticks(days, hours, minutes, seconds, milliseconds, raise_exception)
    # there's no overflow checks for hours, minutes, ...
    # so big hours/minutes values can overflow at some point and change expected values
    hrssec = hours * 3600 # break point at (Int32::MAX - 596523)
    minsec = minutes * 60
    t = (hrssec + minsec + seconds).to_i64 * 1000_i64 + milliseconds.to_i64
    t *= 10000_i64

    result = 0_i64

    overflow = false
    # days is problematic because it can overflow but that overflow can be
    # "legal" (i.e. temporary) (e.g. if other parameters are negative) or
    # illegal (e.g. sign change).
    if days > 0
      td = TicksPerDay * days
      if t < 0
        ticks = t
        t += td
        # positive days -> total ticks should be lower
        overflow = ticks > t
      else
        t += td
        # positive + positive != negative result
        overflow = t < 0
      end
    elsif days < 0
      td = TicksPerDay * days
      if t <= 0
        t += td
        # negative + negative != positive result
        overflow = t > 0
      else
        ticks = t
        t += td
        # negative days -> total ticks should be lower
        overflow = t > ticks
      end
    end

    if overflow
      if raise_exception
        raise ArgumentError.new "Time::Span too big or too small"
      end
      return nil
    end

    t
  end

  def days
    (ticks.tdiv TicksPerDay).to_i32
  end

  def hours
    (ticks.remainder(TicksPerDay).tdiv TicksPerHour).to_i32
  end

  def minutes
    (ticks.remainder(TicksPerHour).tdiv TicksPerMinute).to_i32
  end

  def seconds
    (ticks.remainder(TicksPerMinute).tdiv TicksPerSecond).to_i32
  end

  def milliseconds
    (ticks.remainder(TicksPerSecond).tdiv TicksPerMillisecond).to_i32
  end

  def total_weeks
    total_days / 7
  end

  def total_days
    ticks.to_f / TicksPerDay
  end

  def total_hours
    ticks.to_f / TicksPerHour
  end

  def total_minutes
    ticks.to_f / TicksPerMinute
  end

  def total_seconds
    ticks.to_f / TicksPerSecond
  end

  def to_f
    total_seconds
  end

  def to_i
    ticks / TicksPerSecond
  end

  def total_milliseconds
    ticks.to_f / TicksPerMillisecond
  end

  def duration
    abs
  end

  def abs
    Span.new(ticks.abs)
  end

  def from_now
    Time.now + self
  end

  def ago
    Time.now - self
  end

  def -(other : self)
    # TODO check overflow
    Span.new(ticks - other.ticks)
  end

  def -
    # TODO check overflow
    Span.new(-ticks)
  end

  def +(other : self)
    # TODO check overflow
    Span.new(ticks + other.ticks)
  end

  def +
    self
  end

  def *(number : Number)
    # TODO check overflow
    Span.new(ticks * number)
  end

  def /(number : Number)
    # TODO check overflow
    Span.new(ticks / number)
  end

  def /(other : self)
    ticks.to_f64 / other.ticks.to_f64
  end

  def <=>(other : self)
    ticks <=> other.ticks
  end

  def inspect(io : IO)
    if ticks < 0
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

    fractional = ticks.remainder(TicksPerSecond).abs.to_i32
    if fractional != 0
      io << '.'
      io << '0' if fractional < 1000000
      io << '0' if fractional < 100000
      io << '0' if fractional < 10000
      io << '0' if fractional < 1000
      io << '0' if fractional < 100
      io << '0' if fractional < 10
      io << fractional
    end
  end

  def self.from(value, tick_multiplicator) : self
    # TODO check nan
    # TODO check infinity and overflow
    value = value * (tick_multiplicator / TicksPerMillisecond)
    val = (value < 0 ? (value - 0.5) : (value + 0.5)).to_i64 # round away from zero
    Span.new(val * TicksPerMillisecond)
  end

  def self.zero
    new(0)
  end

  def zero?
    @ticks == 0
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
    Time::Span.new 0, 0, 0, 0, self
  end
end

struct Float
  def days
    Time::Span.from self, Time::Span::TicksPerDay
  end

  def hours
    Time::Span.from self, Time::Span::TicksPerHour
  end

  def minutes
    Time::Span.from self, Time::Span::TicksPerMinute
  end

  def seconds
    Time::Span.from self, Time::Span::TicksPerSecond
  end

  def milliseconds
    Time::Span.from self, Time::Span::TicksPerMillisecond
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
