lib LibC
  struct TimeZone
    tz_minuteswest : Int
    tz_dsttime : Int
  end

  fun gettimeofday(tp : TimeVal*, tzp : TimeZone*) : Int

  ifdef linux
    fun tzset : Void
    $timezone : Int
  end
end

ifdef linux
  LibC.tzset
end

# The `Time` library allows you to inspect, analyze, calculate, and format time. Here are some examples:
#
# ### Basic Usage
#
#     time = Time.now
#     #=> 2016-02-15 10:20:30 UTC
#
#     time.year    #=> 2015
#     time.month   #=> 2
#     time.day     #=> 15
#     time.hour    #=> 10
#     time.minute  #=> 20
#     time.second  #=> 30
#     time.monday? #=> true
#
#     # Creating a time instance with a date only
#     Time.new(2016,2,15)
#     #=> 2016-02-15 00:00:00
#
#     # Specifying a time
#     Time.new(2016,2,15,10,20,30)
#     #=> 2016-02-15 10:20:30 UTC
#
# ### Formatting Time
#
# The `to_s` method returns a `String` value in the assigned format.
#
#     Time.now.to_s("%Y-%m-%d")
#     #=> "2015-10-12"
#
#     # Format specifiers include but are not limited to:
#     %Y  => year
#     %m  => month
#     %d  => day
#     %H  => hour
#     %M  => minute
#     %S  => second
#     %D  => date
#     %u  => weekday
#
# ### Calculation
#
#     Time.new(2015,10,10) - 5.day
#     #=> 2015-10-05 00:00:00
#
#     # Time calculation returns a Time::Span instance,
#     # which can be analyzed with its methods.
#     span = Time.new(2015,10,10) - Time.new(2015,9,10)
#     span.days          #=> 30
#     span.total_hours   #=> 720
#     span.total_minutes #=> 43200
#
#     # Calculation between Time::Span instances
#     span_a = Time::Span.new(3,0,0)
#     span_b = Time::Span.new(2,0,0)
#     span = span_a - span_b
#     span       #=> 02:00:00
#     span.class #=> Time::Span
#     span.hours #=> 2
struct Time
  # *Heavily* inspired by Mono's DateTime class:
  # https://github.com/mono/mono/blob/master/mcs/class/corlib/System/DateTime.cs

  include Comparable(self)

  TicksMask       =      0x3fffffffffffffff
  KindMask        =      0xc000000000000000
  MAX_VALUE_TICKS = 3155378975999999999_i64

  DAYS_MONTH      = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  DAYS_MONTH_LEAP = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  DP400 = 146097
  DP100 =  36524
  DP4   =   1461

  # `Kind` represents a specified time zone.
  #
  # Initializing a `Time` instance with specified `Kind`:
  # ```crystal
  # time = Time.new(2016, 2, 15, 21, 1, 10, 0, Time::Kind::Local)
  # ```
  #
  # Alternatively, you can switch the `Kind` for any instance:
  #
  # ```crystal
  # time.to_utc   # => 2016-02-15 21:00:00 UTC
  # time.to_local # => 2016-02-16 05:01:10 +0800
  # ```
  #
  # Inspection:
  #
  # ```crystal
  # time.local? # => true
  # time.utc?   # => false
  # ```
  #
  enum Kind : Int64
    Unspecified = 0
    Utc         = 1
    Local       = 2
  end

  KindShift = 62_i64

  MaxValue = new 3155378975999999999
  MinValue = new 0

  UnixEpoch = 621355968000000000_i64

  # 1 tick is a tenth of a millisecond
  # The 2 higher bits are reserved for the kind of time.
  @encoded : Int64
  protected property encoded

  def initialize
    initialize Time.local_ticks, kind: Kind::Local
  end

  def initialize(ticks : Int, kind = Kind::Unspecified)
    if ticks < 0 || ticks > MAX_VALUE_TICKS
      raise ArgumentError.new "invalid ticks value"
    end

    @encoded = ticks.to_i64
    @encoded |= kind.value << KindShift
  end

  def initialize(year, month, day, hour = 0, minute = 0, second = 0, millisecond = 0, kind = Kind::Unspecified)
    unless 1 <= year <= 9999 &&
           1 <= month <= 12 &&
           1 <= day <= Time.days_in_month(year, month) &&
           0 <= hour <= 23 &&
           0 <= minute <= 59 &&
           0 <= second <= 59 &&
           0 <= millisecond <= 999
      raise ArgumentError.new "invalid time"
    end

    @encoded = Span.new(Time.absolute_days(year, month, day), hour, minute, second, millisecond).ticks
    @encoded |= kind.value << KindShift
  end

  def self.new(time : LibC::TimeSpec, kind = Kind::Unspecified)
    new(UnixEpoch + time.tv_sec.to_i64 * Span::TicksPerSecond + (time.tv_nsec.to_i64 * 0.01).to_i64, kind)
  end

  def self.epoch(seconds : Int)
    new(UnixEpoch + seconds.to_i64 * Span::TicksPerSecond, Kind::Utc)
  end

  def self.epoch_ms(milliseconds : Int)
    new(UnixEpoch + milliseconds.to_i64 * Span::TicksPerMillisecond, Kind::Utc)
  end

  def +(other : Span)
    add_ticks other.ticks
  end

  def -(other : Span)
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
    month = self.month + months.remainder(12)
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
    Span.new(ticks - other.ticks)
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
    ((encoded & TicksMask) % Span::TicksPerDay / Span::TicksPerHour).to_i32
  end

  def minute
    ((encoded & TicksMask) % Span::TicksPerHour / Span::TicksPerMinute).to_i32
  end

  def second
    ((encoded & TicksMask) % Span::TicksPerMinute / Span::TicksPerSecond).to_i32
  end

  def millisecond
    ((encoded & TicksMask) % Span::TicksPerSecond / Span::TicksPerMillisecond).to_i32
  end

  def time_of_day
    Span.new((encoded & TicksMask) % Span::TicksPerDay)
  end

  def day_of_week
    value = (((encoded & TicksMask) / Span::TicksPerDay) + 1) % 7
    DayOfWeek.new value.to_i
  end

  def day_of_year
    year_month_day_day_year[3]
  end

  # Returns `Kind` of the instance.
  def kind
    Kind.new((encoded.to_u64 >> KindShift).to_i64)
  end

  # Returns *true* if `Kind` is set to *Utc*.
  def utc?
    kind == Kind::Utc
  end

  # Returns *true* if `Kind` is set to *Local*.
  def local?
    kind == Kind::Local
  end

  def <=>(other : self)
    if utc? && other.local?
      self <=> other.to_utc
    elsif local? && other.utc?
      to_utc <=> other
    else
      ticks <=> other.ticks
    end
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
    Format.new("%F %T").format(self, io)
    io << " UTC" if utc?
    Format.new(" %z").format(self, io) if local?
    io
  end

  def to_s(format : String)
    Format.new(format).format(self)
  end

  def to_s(format : String, io : IO)
    Format.new(format).format(self, io)
  end

  def self.parse(time, pattern, kind = Time::Kind::Unspecified)
    Format.new(pattern, kind).parse(time)
  end

  # Returns the number of seconds since the Epoch
  def epoch
    (to_utc.ticks - UnixEpoch) / Span::TicksPerSecond
  end

  def epoch_ms
    (to_utc.ticks - UnixEpoch) / Span::TicksPerMillisecond
  end

  def epoch_f
    (to_utc.ticks - UnixEpoch) / Span::TicksPerSecond.to_f
  end

  def to_utc
    if utc?
      self
    else
      Time.new(Time.compute_utc_ticks(ticks), Kind::Utc)
    end
  end

  def to_local
    if local?
      self
    else
      Time.new(Time.compute_local_ticks(ticks), Kind::Local)
    end
  end

  macro def_at(name)
    def at_{{name.id}}
      year, month, day, day_year = year_month_day_day_year
      mask({{yield}})
    end
  end

  def_at(beginning_of_year) { Time.new(year, 1, 1) }
  def_at(beginning_of_semester) { Time.new(year, ((month - 1) / 6) * 6 + 1, 1) }
  def_at(beginning_of_quarter) { Time.new(year, ((month - 1) / 3) * 3 + 1, 1) }
  def_at(beginning_of_month) { Time.new(year, month, 1) }
  def_at(beginning_of_day) { Time.new(year, month, day) }
  def_at(beginning_of_hour) { Time.new(year, month, day, hour) }
  def_at(beginning_of_minute) { Time.new(year, month, day, hour, minute) }

  def at_beginning_of_week
    dow = day_of_week.value
    if dow == 0
      (self - 6.days).at_beginning_of_day
    else
      (self - (dow - 1).days).at_beginning_of_day
    end
  end

  def_at(end_of_year) { Time.new(year, 12, 31, 23, 59, 59, 999) }

  def at_end_of_semester
    year, month = year_month_day_day_year
    if month <= 6
      month, day = 6, 30
    else
      month, day = 12, 31
    end
    mask Time.new(year, month, day, 23, 59, 59, 999)
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
    mask Time.new(year, month, day, 23, 59, 59, 999)
  end

  def_at(end_of_month) { Time.new(year, month, Time.days_in_month(year, month), 23, 59, 59, 999) }

  def at_end_of_week
    dow = day_of_week.value
    if dow == 0
      at_end_of_day
    else
      (self + (7 - dow).days).at_end_of_day
    end
  end

  def_at(end_of_day) { Time.new(year, month, day, 23, 59, 59, 999) }
  def_at(end_of_hour) { Time.new(year, month, day, hour, 59, 59, 999) }
  def_at(end_of_minute) { Time.new(year, month, day, hour, minute, 59, 999) }
  def_at(midday) { Time.new(year, month, day, 12, 0, 0, 0) }

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

  private def year_month_day_day_year
    m = 1

    days = DAYS_MONTH
    totaldays = ((encoded & TicksMask) / Span::TicksPerDay).to_i32

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
    compute_ticks do |ticks, tp, tz|
      ticks - tz
    end
  end

  def self.utc_ticks
    compute_ticks do |ticks, tp, tz|
      ticks
    end
  end

  # Returns the local time offset in minutes relative to GMT.
  #
  # ```
  # # Assume in Argentina, where it's GMT-3
  # Time.local_offset_in_minutes # => -180
  # ```
  def self.local_offset_in_minutes
    ifdef linux
      -LibC.timezone.to_i32 / 60
    else
      if LibC.gettimeofday(nil, out tzp) != 0
        raise Errno.new("gettimeofday")
      end
      -tzp.tz_minuteswest.to_i32
    end
  end

  protected def self.compute_utc_ticks(ticks)
    compute_ticks do |t, tp, tz|
      ticks + tz
    end
  end

  protected def self.compute_local_ticks(ticks)
    compute_ticks do |t, tp, tz|
      ticks - tz
    end
  end

  private def self.compute_ticks
    if LibC.gettimeofday(out tp, out tzp) != 0
      raise Errno.new("gettimeofday")
    end
    ticks = tp.tv_sec.to_i64 * Span::TicksPerSecond + tp.tv_usec.to_i64 * 10_i64
    ticks += UnixEpoch

    ifdef linux
      tz = LibC.timezone.to_i64 / 60
    else
      tz = tzp.tz_minuteswest.to_i64
    end

    yield ticks, tp, tz * Span::TicksPerMinute
  end
end

require "./**"
