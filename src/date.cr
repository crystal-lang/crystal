struct Date
  def initialize(@year, @month, @day, @calendar = Date::Calendar::DEFAULT)
  end

  include Comparable

  def <=>(other : Date)
    self.jdn <=> other.jdn
  end

  # Returns the Julian Day Number (JDN) as an Int.
  def jdn
    # Algorithm from http://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
    a = ((14 - @month) / 12).floor
    y = @year + 4800 - a
    m = @month + 12 * a - 3
    @day + ((153 * m + 2) / 5).floor + 365 * y + (y / 4).floor - (y / 100).floor + (y / 400).floor - 32045
  end

  def to_s
    "%04d-%02d-%02d" % [@year, @month, @day]
  end
end


struct Date::Calendar
  DEFAULT = nil
end


# A Date::Interval represents a time period consisting of a number of (whole) days.
struct Date::Interval
  def initialize(@number_of_days)
  end

  include Comparable

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
