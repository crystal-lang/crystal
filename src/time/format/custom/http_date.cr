require "./rfc_2822"

struct Time::Format
  # Parse a time string using the formats specified by [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1) and (non-RFC-compliant) [IIS date format](https://docs.microsoft.com/en-us/windows/desktop/wininet/http-cookies#set-cookie-header).
  #
  # Supported formats:
  # * [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55)
  # * [RFC 850](https://tools.ietf.org/html/rfc850#section-2.1.4)
  # * [IIS date format](https://docs.microsoft.com/en-us/windows/desktop/wininet/http-cookies#set-cookie-header)
  # * [asctime](http://en.cppreference.com/w/c/chrono/asctime)
  #
  # ```
  # Time::Format::HTTP_DATE.parse("Sun, 14 Feb 2016 21:00:00 GMT")  # => 2016-02-14 21:00:00 UTC
  # Time::Format::HTTP_DATE.parse("Sunday, 14-Feb-16 21:00:00 GMT") # => 2016-02-14 21:00:00 UTC
  # Time::Format::HTTP_DATE.parse("Sun, 14-Feb-2016 21:00:00 GMT")  # => 2016-02-14 21:00:00 UTC
  # Time::Format::HTTP_DATE.parse("Sun Feb 14 21:00:00 2016")       # => 2016-02-14 21:00:00 UTC
  #
  # Time::Format::HTTP_DATE.format(Time.utc(2016, 2, 15)) # => "Mon, 15 Feb 2016 00:00:00 GMT"
  # ```
  module HTTP_DATE
    # Parses a string into a `Time`.
    def self.parse(string, location = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.http_date
      parser.time(location)
    end

    # Formats a `Time` into the given *io*.
    #
    # *time* is always converted to UTC.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time.to_utc, io)
      formatter.rfc_2822(time_zone_gmt: true, two_digit_day: true)
      io
    end

    # Formats a `Time` into a `String`.
    #
    # *time* is always converted to UTC.
    def self.format(time : Time) : String
      String.build do |io|
        format(time, io)
      end
    end
  end

  struct Parser
    def http_date : Time::Location
      ansi_c_format = http_date_short_day_name_with_comma?

      if ansi_c_format
        return http_date_ansi_c
      end

      day_of_month_zero_padded

      if current_char.ascii_whitespace?
        whitespace
        short_month_name
        whitespace
        year
      else
        char '-'
        short_month_name
        char '-'
        # Intentional departure from standard `year_modulo_100` because of IIS
        # non-RFC-compliant date format, see https://docs.microsoft.com/en-us/windows/desktop/wininet/http-cookies#set-cookie-header
        full_or_short_year
      end

      whitespace
      twenty_four_hour_time_with_seconds
      whitespace
      time_zone_gmt_or_rfc2822
    end

    def http_date_ansi_c : Time::Location
      short_month_name
      whitespace
      day_of_month_blank_padded

      whitespace

      twenty_four_hour_time_with_seconds

      whitespace

      year

      @location = Time::Location::UTC
    end

    def http_date_rfc1123?(ansi_c_format)
      !ansi_c_format && current_char.ascii_whitespace?
    end

    def http_date_short_day_name_with_comma? : Bool
      return false unless current_char.ascii_letter?

      short_day_name

      ansi_c_format = current_char != ','
      next_char unless ansi_c_format

      raise "Invalid date format" unless current_char.ascii_whitespace?
      whitespace

      ansi_c_format
    end
  end
end
