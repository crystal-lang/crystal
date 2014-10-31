struct TimeSpan
  # *Heavily* inspired by Mono's TimeSpan class:
  # https://github.com/mono/mono/blob/master/mcs/class/corlib/System/TimeSpan.cs

  include Comparable(self)

  TicksPerMillisecond = 10_000_i64
  TicksPerSecond      = TicksPerMillisecond * 1000
  TicksPerMinute      = TicksPerSecond * 60
  TicksPerHour        = TicksPerMinute * 60
  TicksPerDay         = TicksPerHour * 24

  MaxValue = new Int64::MAX
  MinValue = new Int64::MIN
  Zero     = new 0

  # 1 tick is a tenth of a millisecond
  @ticks :: Int64

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
    t *= 10000_i64;

    result = 0_i64;

    overflow = false
    # days is problematic because it can overflow but that overflow can be
    # "legal" (i.e. temporary) (e.g. if other parameters are negative) or
    # illegal (e.g. sign change).
    if days > 0
      td = TicksPerDay * days;
      if t < 0
        ticks = t;
        t += td
        # positive days -> total ticks should be lower
        overflow = ticks > t
      else
        t += td
        # positive + positive != negative result
        overflow = t < 0
      end
    elsif days < 0
      td = TicksPerDay * days;
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
        raise ArgumentError.new "TimeSpan too big or too small"
      end
      return nil
    end

    t
  end

  def days
    (ticks / TicksPerDay).to_i32
  end

  def hours
    (ticks % TicksPerDay / TicksPerHour).to_i32
  end

  def minutes
    (ticks % TicksPerHour / TicksPerMinute).to_i32
  end

  def seconds
    (ticks % TicksPerMinute / TicksPerSecond).to_i32
  end

  def milliseconds
    (ticks % TicksPerSecond / TicksPerMillisecond).to_i32
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

  def total_milliseconds
    ticks.to_f / TicksPerMillisecond
  end

  def duration
    abs
  end

  def abs
    TimeSpan.new(ticks.abs)
  end

  def -(other : self)
    # TODO check overflow
    TimeSpan.new(ticks - other.ticks)
  end

  def -
    # TODO check overflow
    TimeSpan.new(-ticks)
  end

  def +(other : self)
    # TODO check overflow
    TimeSpan.new(ticks + other.ticks)
  end

  def +
    self
  end

  def <=>(other : self)
    ticks <=> other.ticks
  end

  def inspect(io : IO)
    if ticks < 0
      io << '-'
    end

    # We need to take absolute values of all components.
    # Can't handle negative timespans by negating the TimeSpan
    # as a whole. This would lead to an overflow for the
    # degenerate case `TimeSpan.MinValue`.
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

    fractional = (ticks % TicksPerSecond).abs.to_i32
    if fractional != 0
      io << '.'
      io << '0' if fractional < 1000000
      io << '0' if fractional <  100000
      io << '0' if fractional <   10000
      io << '0' if fractional <    1000
      io << '0' if fractional <     100
      io << '0' if fractional <      10
      io << fractional
    end
  end

  def self.from(value, tick_multiplicator)
    # TODO check nan
    # TODO check infinity and overflow
    value = value * (tick_multiplicator / TicksPerMillisecond)
      val = (value < 0 ? (value - 0.5)  : (value + 0.5)).to_i64 # round away from zero
    TimeSpan.new(val * TicksPerMillisecond)
  end
end

struct Int
  def day
    days
  end

  def days
    TimeSpan.new self, 0, 0, 0
  end

  def hour
    hours
  end

  def hours
    TimeSpan.new self, 0, 0
  end

  def minute
    minutes
  end

  def minutes
    TimeSpan.new 0, self, 0
  end

  def second
    second
  end

  def seconds
    TimeSpan.new 0, 0, self
  end

  def millisecond
    millisecond
  end

  def milliseconds
    TimeSpan.new 0, 0, 0, 0, self
  end
end

struct Float
  def days
    TimeSpan.from self, TimeSpan::TicksPerDay
  end

  def hours
    TimeSpan.from self, TimeSpan::TicksPerHour
  end

  def minutes
    TimeSpan.from self, TimeSpan::TicksPerMinute
  end

  def seconds
    TimeSpan.from self, TimeSpan::TicksPerSecond
  end

  def milliseconds
    TimeSpan.from self, TimeSpan::TicksPerMillisecond
  end
end
