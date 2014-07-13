# A Date represents a single specific day.
#
# Dates are internally represented by a Julian Day Number (JDN) and a
# calendar system. But you almost never need to worry about those.
# You can just initialize with a year/month/day, and get the year/month/day
# or a String back.
#
# However, the internal representation will allow working with other calendar
# systems, such as the Julian calendar, Hebrew calendar, or Islamic calendar.
#
# A JDN is the number of days from a specific day in the distant past.
# This allows us to abstract away calculations for various calendar systems.
# By storing the JDN as a signed 64-bit integer, we can represent dates as
# far back as the beginning of the universe, so this class can be used for
# historic, geological, and astronomical use cases.
#
# Note, however, that the Gregorian (default calendar) algorithms do not
# handle dates prior to about 4712 BCE.
struct Date

  # Create a date with the given year/month/day in the given calendar system.
  def initialize(year : Int, month : Int, day : Int, @calendar = Date::Calendar.default)
    @jdn = @calendar.ymd_to_jdn(year, month, day)
  end

  # Create a new date for the given Julian Day Number (JDN).
  # We use JDN as our internal representation, to allow us to abstract away date calculations and different calendar systems.
  def initialize(jdn, @calendar = Date::Calendar.default)
    @jdn = jdn.to_i64
  end

  # Allow comparing 2 dates.
  include Comparable(self)
  def <=>(other : Date)
    self.jdn <=> other.jdn
  end

  # A date interval (such as returned by `3.days`) can be added to a date, returning another date.
  def +(days : Date::Interval)
    Date.new(@jdn + days.to_i, @calendar)
  end

  def -(days : Date::Interval)
    Date.new(@jdn - days.to_i, @calendar)
  end

  # Returns the Julian Day Number (JDN) for this date as an Int64.
  getter :jdn

  # Returns the calendar system associated with this date.
  getter :calendar

  def year
    @calendar.jdn_to_ymd(@jdn)[0]
  end

  def month
    @calendar.jdn_to_ymd(@jdn)[1]
  end

  def day
    @calendar.jdn_to_ymd(@jdn)[2]
  end

  def to_s
    "%04d-%02d-%02d" % [year, month, day]
  end
end


struct Date::Calendar
  def self.default
    Date::Calendar::Gregorian.new
  end

  def name
    raise "Subclass must implement."
  end

  def ymd_to_jdn(year : Int, month : Int, day : Int)
    raise "Subclass must implement. Returns an Int64 representing the Julian Day Number (JDN)."
  end

  def jdn_to_ymd(jdn : Int64)
    raise "Subclass must implement. Returns a Tuple representing the year, month, and day as Ints."
  end
end


# NOTE: This is technically proleptic Gregorian. See http://en.wikipedia.org/wiki/Gregorian_calendar#Proleptic_Gregorian_calendar for details.
struct Date::Calendar::Gregorian < Date::Calendar
  def name
    "Gregorian"
  end

  def ymd_to_jdn(year : Int, month : Int, day : Int)
    # Algorithm from http://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
    a = ((14 - month) / 12).floor
    y = year + 4800 - a
    m = month + 12 * a - 3
    jdn = (day + ((153 * m + 2) / 5).floor + 365 * y + (y / 4).floor - (y / 100).floor + (y / 400).floor - 32045)
    jdn.to_i64
   end

  def jdn_to_ymd(jdn : Int64)
    # Algorithm from http://quasar.as.utexas.edu/BillInfo/JulianDatesG.html
    raise "Algorithm for Gregorian dates does support JDNs < 0 (about 4712 BCE)" if jdn < 0
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
    {year, month, day}
  end
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

  def -(other : Date::Interval)
    Date::Interval.new(self.to_i - other.to_i)
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
