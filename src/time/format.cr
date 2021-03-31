require "./format/formatter"
require "./format/parser"

# Specifies the format to convert a `Time` to and from a `String`.
#
# The pattern of a format is a `String` with directives. Directives
# being with a percent (`%`) character. Any text not listed as a directive
# will be passed/parsed through the output/input string.
#
# The directives are:
#
# * **%a**: short day name (Sun, Mon, Tue, ...)
# * **%^a**: short day name, upcase (SUN, MON, TUE, ...)
# * **%A**: day name (Sunday, Monday, Tuesday, ...)
# * **%^A**: day name, upcase (SUNDAY, MONDAY, TUESDAY, ...)
# * **%b**: short month name (Jan, Feb, Mar, ...)
# * **%^b**: short month name, upcase (JAN, FEB, MAR, ...)
# * **%B**: month name (January, February, March, ...)
# * **%^B**: month name, upcase (JANUARY, FEBRUARY, MARCH, ...)
# * **%c**: date and time (Tue Apr  5 10:26:19 2016)
# * **%C**: year divided by 100
# * **%d**: day of month, zero padded (01, 02, ...)
# * **%-d**: day of month (1, 2, ..., 31)
# * **%D**: date (04/05/16)
# * **%e**: day of month, blank padded (" 1", " 2", ..., "10", "11", ...)
# * **%F**: ISO 8601 date (2016-04-05)
# * **%g**: week-based calendar year modulo 100 (00..99)
# * **%G**: week-based calendar year (0001..9999)
# * **%h**: (same as %b) short month name (Jan, Feb, Mar, ...)
# * **%H**: hour of the day, 24-hour clock, zero padded (00, 01, ..., 24)
# * **%I**: hour of the day, 12-hour clock, zero padded (00, 01, ..., 12)
# * **%j**: day of year, zero padded (001, 002, ..., 365)
# * **%k**: hour of the day, 24-hour clock, blank padded (" 0", " 1", ..., "24")
# * **%l**: hour of the day, 12-hour clock, blank padded (" 0", " 1", ..., "12")
# * **%L**: milliseconds, zero padded (000, 001, ..., 999) (same as **%3N**)
# * **%m**: month number, zero padded (01, 02, ..., 12)
# * **%_m**: month number, blank padded (" 1", " 2", ..., "12")
# * **%-m**: month number (1, 2, ..., 12)
# * **%M**: minute, zero padded (00, 01, 02, ..., 59)
# * **%3N**: milliseconds, zero padded (000, 001, ..., 999) (same as **%L**)
# * **%6N**: microseconds, zero padded (000000, 000001, ..., 999999)
# * **%9N**: nanoseconds, zero padded (000000000, 000000001, ..., 999999999)
# * **%N**: second fraction, zero padded. (Same as `%9N` but may consume more than 9 digits while parsing)
# * **%p**: am-pm (lowercase)
# * **%P**: AM-PM (uppercase)
# * **%r**: 12-hour time (03:04:05 AM)
# * **%R**: 24-hour time (13:04)
# * **%s**: seconds since unix epoch (see `Time#to_unix`)
# * **%S**: seconds, zero padded (00, 01, ..., 59)
# * **%T**: 24-hour time (13:04:05)
# * **%u**: day of week (Monday is 1, 1..7)
# * **%V**: ISO calendar week number of the week-based year (01..53)
# * **%w**: day of week (Sunday is 0, 0..6)
# * **%x**: (same as %D) date (04/05/16)
# * **%X**: (same as %T) 24-hour time (13:04:05)
# * **%y**: year modulo 100
# * **%Y**: year, zero padded
# * **%z**: time zone offset from UTC as hour and minute with no separator (+0900)
# * **%:z**: time zone offset from UTC as hour and minute separated by colon (+09:00)
# * **%::z**: time zone offset from UTC as hour, minute and second separated by colon (+09:00:00)
# * **%Z**: location name or offset (e.g. `Europe/Berlin`)
# * **%^Z**: abbreviated time zone identifier or offset (e.g. `CET`)
struct Time::Format
  # :nodoc:
  MONTH_NAMES = %w(January February March April May June July August September October November December)

  # :nodoc:
  DAY_NAMES = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

  # Error raised when an invalid pattern is used.
  class Error < ::Exception
  end

  # Returns the string pattern of this format.
  getter pattern : String

  # Creates a new `Time::Format` with the given *pattern*. The given time
  # *location* will be used when parsing a `Time` and no time zone is found in it.
  def initialize(@pattern : String, @location : Location? = nil)
  end

  # Parses a string into a `Time`.
  def parse(string, location = @location) : Time
    parser = Parser.new(string)
    parser.visit(pattern)
    parser.time(location)
  end

  # Turns a `Time` into a `String`.
  def format(time : Time) : String
    String.build do |str|
      format time, str
    end
  end

  # Formats a `Time` into the given *io*.
  def format(time : Time, io : IO) : Nil
    formatter = Formatter.new(time, io)
    formatter.visit(pattern)
  end
end

require "./format/custom/*"
