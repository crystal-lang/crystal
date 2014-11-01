require "./**"

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

  include Comparable(self)

  TicksMask = 4611686018427387903 # TODO replace with 0x3fffffffffffffff after 0.5.1
  KindMask = 1383505805528216371_u64 * 10 + 2 # TODO replace with 0xc000000000000000 after 0.5.1
  MAX_VALUE_TICKS = 3155378975999999999_i64

  DAYS_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  DAYS_MONTH_LEAP = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  DP400 = 146097
  DP100 = 36524
  DP4   = 1461

  module Kind
    Unspecified = 0_i64
    Utc         = 1_i64
    Local       = 2_i64
  end

  KindShift = 62_i64

  MaxValue = new 3155378975999999999
  MinValue = new 0

  UnixEpoch = 621355968000000000_i64

  # 1 tick is a tenth of a millisecond
  # The 2 higher bits are reserved for the kind of time.
  @encoded :: Int64
  protected property encoded

  def initialize
    initialize Time.local_ticks
  end

  def initialize(ticks : Int, kind = Kind::Local)
    if ticks < 0 || ticks > MAX_VALUE_TICKS
      raise ArgumentError.new "invalid ticks value"
    end

    @encoded = ticks.to_i64
    @encoded |= kind << KindShift
  end

  def initialize(year, month, day, hour = 0, minute = 0, second = 0, millisecond = 0, kind = Kind::Local)
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
    @encoded |= kind << KindShift
  end

  def +(other : TimeSpan)
    add_ticks other.ticks
  end

  def -(other : TimeSpan)
    add_ticks -other.ticks
  end

  def +(other : MonthSpan)
    add_months other.value
  end

  def -(other : MonthSpan)
    add_months -other.value
  end

  private def add_months(months)
    day = self.day
    month = self.month + (months % 12)
    year = self.year + (months / 12)

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

    temp = mask Time.new(year, month, day)
    temp + time_of_day
  end

  def add_ticks(value)
    res = (value + (encoded & TicksMask)).to_i64
    unless 0 <= res <= MAX_VALUE_TICKS
      raise ArgumentError.new "invalid time"
    end

    mask Time.new(res)
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

  def self.utc_now
    new utc_ticks, Kind::Utc
  end

  def ticks
    encoded & TicksMask
  end

  def date
    mask Time.new(year, month, day)
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

  def time_of_day
    TimeSpan.new((encoded & TicksMask) % TimeSpan::TicksPerDay)
  end

  def day_of_week
    (((encoded & TicksMask) / TimeSpan::TicksPerDay) + 1) % 7
  end

  def day_of_year
    year_month_day_day_year[3]
  end

  def kind
    encoded.to_u64 >> KindShift
  end

  def utc?
    kind == Kind::Utc
  end

  def local?
    kind == Kind::Local
  end

  def <=>(other : self)
    ticks <=> other.ticks
  end

  def hash
    @encoded
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
    TimeFormat.new("%F %T").format(self, io)
    if utc?
      io << " UTC"
    end
    io
  end

  def to_s(format : String)
    TimeFormat.new(format).format(self)
  end

  def to_s(format : String, io : IO)
    TimeFormat.new(format).format(self, io)
  end

  def self.parse(time, pattern)
    TimeFormat.new(pattern).parse(time)
  end

  macro def_at(name)
    def at_{{name.id}}
      year, month, day, day_year = year_month_day_day_year
      mask({{yield}})
    end
  end

  def_at(beginning_of_year)    { Time.new(year, 1, 1) }
  def_at(beginning_of_quarter) { Time.new(year, ((month - 1) / 3) * 3 + 1, 1) }
  def_at(beginning_of_month)   { Time.new(year, month, 1) }
  def_at(beginning_of_day)     { Time.new(year, month, day) }
  def_at(beginning_of_hour)    { Time.new(year, month, day, hour) }
  def_at(beginning_of_minute)  { Time.new(year, month, day, hour, minute) }

  def at_beginning_of_week
    dow = day_of_week
    if dow == 0
      (self - 6.days).at_beginning_of_day
    else
      (self - (dow - 1).days).at_beginning_of_day
    end
  end

  def_at(end_of_year) { Time.new(year, 12, 31, 23, 59, 59, 999) }

  def at_end_of_quarter
    year, month = year_month_day_day_year
    if month <= 6
      mask Time.new(year, 6, 30, 23, 59, 59, 999)
    else
      mask Time.new(year, 12, 31, 23, 59, 59, 999)
    end
  end

  def_at(end_of_month) { Time.new(year, month, Time.days_in_month(year, month), 23, 59, 59, 999) }

  def at_end_of_week
    dow = day_of_week
    if dow == 0
      at_end_of_day
    else
      (self + (7 - day_of_week).days).at_end_of_day
    end
  end

  def_at(end_of_day)    { Time.new(year, month, day, 23, 59, 59, 999) }
  def_at(end_of_hour)   { Time.new(year, month, day, hour, 59, 59, 999) }
  def_at(end_of_minute) { Time.new(year, month, day, hour, minute, 59, 999) }
  def_at(midday)        { Time.new(year, month, day, 12, 0, 0, 0) }

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

  private def year_month_day_day_year
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

    {year, month, day, day_year}
  end

  private def mask(time)
    time.encoded |= encoded & KindMask
    time
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

  def self.utc_ticks
    # FIXME spec uses Time.now before main so the consts don't get initialized
    ticks_per_second = 10_000_000_i64
    ticks_per_minute = 600_000_000_i64

    # TODO use clock_gettime in linux, but find a fast function to get the local timezone
    C.gettimeofday(out tp, out tzp)
    ticks = tp.tv_sec.to_i64 * ticks_per_second + tp.tv_usec.to_i64 * 10_i64
    ticks += UnixEpoch
    ticks
  end
end
