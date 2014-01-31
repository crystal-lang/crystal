class Date
  def initialize(@year, @month, @day, @calendar = Date::Calendar::DEFAULT)
  end

  def to_s
    "%04d-%02d-%02d" % [@year, @month, @day]
  end
end


class Date::Calendar
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
