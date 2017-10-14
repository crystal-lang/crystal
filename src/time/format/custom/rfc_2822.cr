# The [RFC 2822](https://tools.ietf.org/html/rfc2822) datetime format.
#
# This is also compatible to [RFC 882](https://tools.ietf.org/html/rfc882) and [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
module Time::Format::RFC_2822
  extend Format

  # :nodoc:
  module Visitor
    def visit
      cfws?
      short_day_name_with_comma?
      day_of_month
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

      time_zone_rfc2822

      cfws?
    end
  end

  # :nodoc:
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

    # comment or folding white space
    def cfws?
      in_comment = false
      seen_whitespace = false
      loop do
        case char = current_char
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

  # :nodoc:
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
