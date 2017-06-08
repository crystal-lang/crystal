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
  def initialize(year : Int, month : Int, day : Int, @calendar = Date::Calendar.default : Date::Calendar)
    @jdn = @calendar.ymd_to_jdn(year, month, day)
  end
  def initialize(year : Int, month : Int, day : Int, calendar : Class)
    @calendar = calendar.new
    @jdn = @calendar.ymd_to_jdn(year, month, day)
  end

  # Create a new date for the given Julian Day Number (JDN).
  # We use JDN as our internal representation, to allow us to abstract away date calculations and different calendar systems.
  def initialize(jdn, @calendar = Date::Calendar.default : Date::Calendar)
    @jdn = jdn.to_i64
  end
  def initialize(jdn, calendar : Class)
    @calendar = calendar.new
    @jdn = jdn.to_i64
  end

  # Allow comparing 2 dates.
  include Comparable(self)
  def <=>(other : Date)
    self.jdn <=> other.jdn
  end

  # A date interval (such as returned by `3.days`) can be added to a date, returning another date.
  def +(days : Date::Interval)
    Date.new(jdn + days.to_i, calendar)
  end

  def -(days : Date::Interval)
    Date.new(jdn - days.to_i, calendar)
  end

  # Returns the Julian Day Number (JDN) for this date as an Int64.
  getter :jdn

  # Returns the calendar system associated with this date.
  getter :calendar

  def year
    calendar.jdn_to_ymd(jdn)[0]
  end

  def month
    calendar.jdn_to_ymd(jdn)[1]
  end

  def day
    calendar.jdn_to_ymd(jdn)[2]
  end

  def to_s
    "%04d-%02d-%02d" % [year, month, day]
  end
end


struct Date::Calendar
  def self.default
    # We're defaulting to the date that Britain and her colonies switched from Julian to Gregorian.
    # For the dates that other countries switched, see http://www.tondering.dk/claus/cal/gregorian.php.
    first_day_of_julian_calendar = Date.new(Int64::MIN, Date::Calendar::Julian)
    first_day_of_gregorian_calendar = Date.new(1752, 9, 14, Date::Calendar::Gregorian)
    Date::Calendar::Multiple.new({first_day_of_julian_calendar => Date::Calendar::Julian,
                                  first_day_of_gregorian_calendar => Date::Calendar::Gregorian})
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


struct Date::Calendar::Multiple < Date::Calendar
  def name
    "MULTIPLE" # TODO: Show all the names and the transition dates.
  end

  def initialize(date_to_calendar_mapping : Hash(Date, Class))
    @jdn_to_calendar_mapping = Hash(Int64, Date::Calendar).new
    date_to_calendar_mapping.each do |k, v|
      @jdn_to_calendar_mapping[k.jdn] = v.new
    end
  end

  def ymd_to_jdn(year : Int, month : Int, day : Int)
    jdn = Int64::MIN
    @jdn_to_calendar_mapping.each_with_index do |calendar_start_jdn, calendar, index|
      if calendar.ymd_to_jdn(year, month, day) < calendar_start_jdn
        return jdn
      end
      jdn = calendar.ymd_to_jdn(year, month, day)
    end
    return jdn
  end

  def jdn_to_ymd(jdn : Int64)
    earliest_jdn = @jdn_to_calendar_mapping.keys.min
    raise "No calendar system for that JDN" if jdn < earliest_jdn
    # Cycle through hash of JDNs until we reach a JDN higher than `jdn`. Then use the previous calendar.
    # NOTE: This assumes that the @jdn_to_calendar_mapping is an ordered hash, in JDN-increasing order.
    @jdn_to_calendar_mapping.each_with_index do |calendar_start_jdn, calendar, index|
      if jdn < calendar_start_jdn
        previous_calendar_jdn = @jdn_to_calendar_mapping.keys[index - 1]
        previous_calendar = @jdn_to_calendar_mapping[previous_calendar_jdn]
        return previous_calendar.jdn_to_ymd(jdn)
      end
    end
    last_calendar_jdn = @jdn_to_calendar_mapping.keys.last
    last_calendar = @jdn_to_calendar_mapping[last_calendar_jdn]
    return last_calendar.jdn_to_ymd(jdn)
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


# NOTE: This is technically proleptic Julian. See http://en.wikipedia.org/wiki/Proleptic_Julian_calendar for details.
struct Date::Calendar::Julian < Date::Calendar
  def name
    "Julian"
  end

  def ymd_to_jdn(year : Int, month : Int, day : Int)
    # Algorithm from http://en.wikipedia.org/wiki/Julian_day#Converting_Julian_or_Gregorian_calendar_date_to_Julian_Day_Number
    a = ((14 - month) / 12).floor
    y = year + 4800 - a
    m = month + 12 * a - 3
    jdn = (day + ((153 * m + 2) / 5).floor + 365 * y + (y / 4).floor - 32083)
    jdn.to_i64
   end

  def jdn_to_ymd(jdn : Int64)
    # Algorithm from http://www.tondering.dk/claus/cal/julperiod.php#formula
    raise "Algorithm for Julian dates does support JDNs < 0 (about 4712 BCE)" if jdn < 0
    b = 0
    c = jdn + 32082
    d = ((4 * c + 3) / 1461).floor
    e = c - (1461 * d / 4).floor
    m = ((5 * e + 2) / 153).floor
    day = e - ((153 * m + 2) / 5).floor + 1
    month = m + 3 - 12 * (m / 10).floor
    year = 100 * b + d - 4800 + (m / 10).floor
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

  getter :number_of_days

  def to_i
    number_of_days
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
