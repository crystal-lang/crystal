class Date
  def initialize(@year, @month, @day, @calendar = Date::Calendar::DEFAULT)
  end
end


class Date::Calendar
  DEFAULT = nil
end
