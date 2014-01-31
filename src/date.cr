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
