# Parse a time string using the formats specified by [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1).
#
# Supported formats:
# * [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55)
# * [RFC 850](https://tools.ietf.org/html/rfc850#section-2.1.4)
# * [asctime](http://en.cppreference.com/w/c/chrono/asctime)
#
# ```
# HTTP::HTTP_DATE.parse("Sun, 14 Feb 2016 21:00:00 GMT")  # => 2016-02-14 21:00:00 UTC
# HTTP::HTTP_DATE.parse("Sunday, 14-Feb-16 21:00:00 GMT") # => 2016-02-14 21:00:00 UTC
# HTTP::HTTP_DATE.parse("Sun Feb 14 21:00:00 2016")       # => 2016-02-14 21:00:00 UTC
#
# HTTP::HTTP_DATE.format(Time.new(2016, 2, 15)) # => "Sun, 14 Feb 2016 21:00:00 GMT"
# ```
module HTTP::HTTP_DATE
  extend Time::Format

  # :nodoc:
  module Visitor
    @ansi_c_format = false

    def visit
      short_day_name_with_comma?

      if @ansi_c_format
        return visit_ansi_c
      end

      day_of_month_zero_padded

      if rfc1123?
        whitespace
        short_month_name
        whitespace
        year
      else
        char '-'
        short_month_name
        char '-'
        year_modulo_100
      end

      whitespace
      twenty_four_hour_time_with_seconds
      whitespace
      time_zone_gmt_or_rfc2822
    end

    def visit_ansi_c
      short_month_name
      whitespace
      day_of_month_blank_padded

      whitespace

      twenty_four_hour_time_with_seconds

      whitespace

      year

      @kind = Time::Kind::Utc
    end
  end

  # :nodoc:
  struct Parser
    def rfc1123?
      !@ansi_c_format && current_char.ascii_whitespace?
    end

    def short_day_name_with_comma?
      return unless current_char.ascii_letter?

      short_day_name

      @ansi_c_format = current_char != ','
      next_char unless @ansi_c_format

      whitespace
    end
  end

  # :nodoc:
  struct Formatter
    def initialize(time : Time, io : IO)
      super(time.to_utc, io)
    end

    def rfc1123?
      true
    end
  end
end
