struct Time::Format
  # The [RFC 2822](https://tools.ietf.org/html/rfc2822) datetime format.
  #
  # This is also compatible to [RFC 882](https://tools.ietf.org/html/rfc882) and [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
  #
  # ```
  # Time::Format::RFC_2822.format(Time.utc(2016, 2, 15, 4, 35, 50)) # => "Mon, 15 Feb 2016 04:35:50 +0000"
  #
  # Time::Format::RFC_2822.parse("Mon, 15 Feb 2016 04:35:50 +0000") # => 2016-02-15 04:35:50.0 +00:00
  # Time::Format::RFC_2822.parse("Mon, 15 Feb 2016 04:35:50 UTC")   # => 2016-02-15 04:35:50.0 UTC
  # ```
  module RFC_2822
    # Parses a string into a `Time`.
    def self.parse(string, kind = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.rfc_2822
      parser.time(kind)
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time, io)
      formatter.rfc_2822
      io
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time) : String
      String.build do |io|
        format(time, io)
      end
    end
  end

  module Pattern
    def rfc_2822(time_zone_gmt = false, two_digit_day = false)
      cfws?
      short_day_name_with_comma?
      if two_digit_day
        day_of_month_zero_padded
      else
        day_of_month
      end
      cfws
      short_month_name
      cfws
      full_or_short_year

      folding_white_space

      cfws?
      hour_24_zero_padded
      cfws?
      char ':'
      cfws?
      minute
      cfws?
      seconds_with_colon?

      folding_white_space

      if time_zone_gmt
        time_zone_gmt_or_rfc2822
      else
        time_zone_rfc2822
      end

      cfws?
    end
  end

  struct Parser
    def short_day_name_with_comma?
      return unless current_char.ascii_letter?

      short_day_name
      cfws?
      char ','
      cfws
    end

    def seconds_with_colon?
      if current_char == ':'
        next_char
        cfws?
        second
      end
    end

    # comment or folding whitespace
    def cfws?
      in_comment = false
      seen_whitespace = false
      loop do
        case current_char
        when .ascii_whitespace?
          seen_whitespace = true
        when '('
          in_comment = true
        when ')'
          in_comment = false
        else
          break unless in_comment
        end
        break unless @reader.has_next?
        next_char
      end
      seen_whitespace
    end

    def cfws
      cfws? || raise "Invalid format"
    end

    def folding_white_space
      skip_space
    end
  end

  struct Formatter
    def seconds_with_colon?
      char ':'
      second
    end

    def cfws?
    end

    def cfws
      folding_white_space
    end

    def folding_white_space
      io << ' '
    end
  end
end
