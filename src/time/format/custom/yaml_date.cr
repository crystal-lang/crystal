struct Time::Format
  # Even though the standard library has Time parsers given a *fixed* format,
  # the format in YAML, http://yaml.org/type/timestamp.html,
  # can consist of just the date part, and following it any number of spaces,
  # or 't', or 'T' can follow, with many optional components. So, we implement
  # this in a more efficient way to avoid parsing the same string with many
  # possible formats (there's also no way to specify any number of spaces
  # with Time::Format, or an "or" like in a Regex).
  #
  # As an additional note, Ruby's Psych YAML parser also implements a
  # custom time parser, probably for this same reason.
  module YAML_DATE
    # Parses a string into a `Time`.
    def self.parse?(string) : Time?
      parser = Parser.new(string)
      if parser.yaml_date_time?
        parser.time(Time::Location::UTC) rescue nil
      else
        nil
      end
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time, io)

      if time.hour == 0 && time.minute == 0 && time.second == 0 && time.nanosecond == 0
        formatter.year_month_day_iso_8601
      else
        formatter.yaml_date_time
      end
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time) : String
      String.build do |io|
        format(time, io)
      end
    end
  end

  struct Parser
    def yaml_date_time?
      if (year = consume_number?(4)) && char?('-')
        @year = year
      else
        return false
      end

      if (month = consume_number?(2)) && char?('-')
        @month = month
      else
        return false
      end

      if day = consume_number?(2)
        @day = day
      else
        return false
      end

      case current_char
      when 'T', 't'
        next_char
        return yaml_time?
      when .ascii_whitespace?
        skip_spaces

        if @reader.has_next?
          return yaml_time?
        end
      else
        if @reader.has_next?
          return false
        end
      end

      true
    end

    def yaml_time?
      if (hour = consume_number?(2)) && char?(':')
        @hour = hour
      else
        return false
      end

      if (minute = consume_number?(2)) && char?(':')
        @minute = minute
      else
        return false
      end

      if second = consume_number?(2)
        @second = second
      else
        return false
      end

      second_fraction?

      skip_spaces

      if @reader.has_next?
        begin
          time_zone_z_or_offset(force_zero_padding: false, force_minutes: false)
        rescue Time::Format::Error
          return false
        end

        return false if @reader.has_next?
      end

      true
    end
  end

  struct Formatter
    def yaml_date_time
      year_month_day
      char ' '
      twenty_four_hour_time_with_seconds
      second_fraction?

      unless time.utc?
        time_zone_z_or_offset(force_colon: true)
      end
    end
  end
end
