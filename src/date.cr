struct Date
  def initialize(@year, @month, @day, @calendar = Date::Calendar::DEFAULT)
    # Algorithm from http://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
    a = ((14 - @month) / 12).floor
    y = @year + 4800 - a
    m = @month + 12 * a - 3
    @jdn = @day + ((153 * m + 2) / 5).floor + 365 * y + (y / 4).floor - (y / 100).floor + (y / 400).floor - 32045
  end

  def self.for_jdn(jdn)
    ymd = ymd(jdn)
    Date.new(ymd[0], ymd[1], ymd[2])
  end

  # Allow comparing 2 dates.
  include Comparable(self)
  def <=>(other : Date)
    self.jdn <=> other.jdn
  end

  # A date interval (such as returned by `3.days`) can be added to a date, returning another date.
  def +(days : Date::Interval)
    Date.for_jdn(@jdn + days.to_i)
  end

  # Returns the Julian Day Number (JDN) as an Int.
  getter :jdn

  def self.ymd(jdn)
    # Algorithm from http://quasar.as.utexas.edu/BillInfo/JulianDatesG.html
    q = jdn
    z = jdn
    w = ((z - 1867216.25) / 36524.25).floor
    x = (w / 4).floor
    a = z + 1 + w - x
    b = a + 1524
    c = ((b - 122.1) / 365.25).floor
    d = (365.25 * c).floor
    e = ((b - d) / 30.6001).floor
    f = (30.6001 * e).floor
    day = b - d - f + (q - z)
    month = (e - 1) <= 12 ? (e - 1) : (e - 13)
    year = c - 4715 - (month > 2 ? 1 : 0)
    [year, month, day]
  end

  def year
    Date.ymd(@jdn)[0]
  end

  def month
    Date.ymd(@jdn)[1]
  end

  def day
    Date.ymd(@jdn)[2]
  end

  def to_s
    "%04d-%02d-%02d" % [year, month, day]
  end
end


struct Date::Calendar
  DEFAULT = nil
end


# A Date::Interval represents a time period consisting of a number of (whole) days.
struct Date::Interval
  def initialize(@number_of_days)
  end

  include Comparable(self)

  def <=>(other : Date::Interval)
    self.to_i <=> other.to_i
  end

  def +(other : Date::Interval)
    Date::Interval.new(self.to_i + other.to_i)
  end

  def to_i
    @number_of_days
  end

  def inspect
    to_i
  end
end


struct Int
  # Create a Date::Interval for the given number of days.
  def days
    Date::Interval.new(self)
  end
end
