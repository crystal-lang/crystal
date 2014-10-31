require "./*"

lib C
  struct TimeSpec
    tv_sec  : C::TimeT
    tv_nsec : C::TimeT
  end

  struct TimeVal
    tv_sec  : C::TimeT
    tv_usec : Int32
  end

  struct TimeZone
    tz_minuteswest : Int32
    tz_dsttime     : Int32
  end

  fun gettimeofday(tp : TimeVal*, tzp : TimeZone*) : Int32
end

struct Time
  # *Heavily* inspired by Mono's DateTime class:
  # https://github.com/mono/mono/blob/master/mcs/class/corlib/System/DateTime.cs

  TicksMask = 4611686018427387903 # TODO replace with 0x3fffffffffffffff after 0.5.1
  KindMask = 1383505805528216371_u64 * 10 + 2 # TODO replace with 0xc000000000000000 after 0.5.1
  MAX_VALUE_TICKS = 3155378975999999999_i64

  DAYS_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  DAYS_MONTH_LEAP = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  DP400 = 146097
  DP100 = 36524
  DP4   = 1461

  MaxValue = new 3155378975999999999
  MinValue = new 0

  KindShift = 62_i64

  UnixEpoch = 621355968000000000_i64

  module Kind
    Unspecified = 0_i64
    Utc         = 1_i64
    Local       = 2_i64
  end

  # 1 tick is a tenth of a millisecond
  # The 2 higher bits are reserved for the kind of time.
  @encoded :: Int64
  protected property encoded

  def initialize
    @encoded = Time.local_ticks
    @encoded |= Kind::Local << KindShift
  end

  def initialize(ticks)
    if ticks < 0 || ticks > MAX_VALUE_TICKS
      raise ArgumentError.new "invalid ticks value"
    end

    @encoded = ticks.to_i64
  end

  def initialize(year, month, day, hour = 0, minute = 0, second = 0, millisecond = 0)
    unless 1 <= year <= 9999 &&
           1 <= month <= 12 &&
           1 <= day <= Time.days_in_month(year, month) &&
           0 <= hour <= 23 &&
           0 <= minute <= 59 &&
           0 <= second <= 59 &&
           0 <= millisecond <= 999
      raise ArgumentError.new "invalid time"
    end

    @encoded = TimeSpan.new(Time.absolute_days(year, month, day), hour, minute, second, millisecond).ticks
  end

  def +(other : TimeSpan)
    add_ticks other.ticks
  end

  def -(other : TimeSpan)
    add_ticks -other.ticks
  end

  def add_ticks(value)
    res = (value + (encoded & TicksMask)).to_i64
    unless 0 <= res <= MAX_VALUE_TICKS
      raise ArgumentError.new "invalid time"
    end

    ret = Time.new res
    ret.encoded |= encoded & KindMask
    ret
  end

  def -(other : Int)
    Time.new(ticks - other)
  end

  def -(other : Time)
    TimeSpan.new(ticks - other.ticks)
  end

  def self.now
    new
  end

  def ticks
    encoded & TicksMask
  end

  def date
    ret = Time.new year, month, day
    ret.encoded |= encoded & KindMask
    ret
  end

  def year
    from_ticks :year
  end

  def month
    from_ticks :month
  end

  def day
    from_ticks :day
  end

  def hour
    ((encoded & TicksMask) % TimeSpan::TicksPerDay / TimeSpan::TicksPerHour).to_i32
  end

  def minute
    ((encoded & TicksMask) % TimeSpan::TicksPerHour / TimeSpan::TicksPerMinute).to_i32
  end

  def second
    ((encoded & TicksMask) % TimeSpan::TicksPerMinute / TimeSpan::TicksPerSecond).to_i32
  end

  def millisecond
    ((encoded & TicksMask) % TimeSpan::TicksPerSecond / TimeSpan::TicksPerMillisecond).to_i32
  end

  def self.days_in_month(year, month)
    unless 1 <= month <= 12
      raise ArgumentError.new "invalid month"
    end

    unless 1 <= year <= 9999
      raise ArgumentError.new "invalid year"
    end

    days = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH
    days[month]
  end

  def self.leap_year?(year)
    unless 1 <= year <= 9999
      raise ArgumentError.new "invalid year"
    end

    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
  end

  def inspect(io : IO)
    io << year
    io << '-'

    m = month
    io << '0' if m < 10
    io << m
    io << '-'

    d = day
    io << '0' if d < 10
    io << d
    io << ' '

    h = hour
    io << '0' if h < 10
    io << h
    io << ':'

    m = minute
    io << '0' if m < 10
    io << m
    io << ':'

    s = second
    io << '0' if s < 10
    io << s
  end

  protected def self.absolute_days(year, month, day)
    days = leap_year?(year) ? DAYS_MONTH_LEAP : DAYS_MONTH

    temp = 0
    m = 1
    while m < month
      temp += days[m]
      m += 1
    end

    (day-1) + temp + (365* (year-1)) + ((year-1)/4) - ((year-1)/100) + ((year-1)/400)
  end

  private def from_ticks(what)
    m = 1

    days = DAYS_MONTH
    totaldays = ((encoded & TicksMask) / TimeSpan::TicksPerDay).to_i32

    num400 = totaldays / DP400
    totaldays -= num400 * DP400

    num100 = totaldays / DP100
    if num100 == 4 # leap
      num100 = 3
    end
    totaldays -= num100 * DP100

    num4 = totaldays / DP4
    totaldays -= num4 * DP4

    numyears = totaldays / 365

    if numyears == 4 # leap
      numyears = 3
    end

    if what == :year
      return num400*400 + num100*100 + num4*4 + numyears + 1
    end

    totaldays -= numyears * 365
    if what == :day_year
      return totaldays + 1
    end

    if (numyears == 3) && ((num100 == 3) || !(num4 == 24)) # 31 dec leapyear
      days = DAYS_MONTH_LEAP
    end

    while totaldays >= days[m]
      totaldays -= days[m]
      m += 1
    end

    if what == :month
      return m
    end

    totaldays + 1
  end

  def self.local_ticks
    # FIXME spec uses Time.now before main so the consts don't get initialized
    ticks_per_second = 10_000_000_i64
    ticks_per_minute = 600_000_000_i64

    # TODO use clock_gettime in linux, but find a fast function to get the local timezone
    C.gettimeofday(out tp, out tzp)
    ticks = tp.tv_sec.to_i64 * ticks_per_second + tp.tv_usec.to_i64 * 10_i64
    ticks += UnixEpoch
    ticks -= tzp.tz_minuteswest.to_i64 * ticks_per_minute
    ticks
  end
end
