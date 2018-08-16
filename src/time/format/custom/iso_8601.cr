struct Time::Format
  module Pattern
    def date_time_iso_8601
      year_month_day_iso_8601
      char? 'T'
      time_iso_8601
    end

    def time_iso_8601
      hour_minute_second_iso8601
      time_zone_z_or_offset
    end
  end

  struct Parser
    def year_month_day_iso_8601
      year
      extended_format = char? '-'
      if current_char == 'W'
        # week date
        next_char

        week = consume_number(2)
        extended_format ? char('-') : char?('-')

        day_of_week = consume_number(1)

        first_day_of_year = Time.utc(@year, 1, 1)
        week_day = first_day_of_year.day_of_week.value

        if week_day < 5
          first_day_in_weeks_of_year = first_day_of_year - (week_day % 7 - 1).days
        else
          first_day_in_weeks_of_year = first_day_of_year + ((week_day - 4) % 7).days
        end

        days_in_year = (week - 1) * 7 + day_of_week - 1

        date = first_day_in_weeks_of_year + days_in_year.days

        @year = date.year
        @month = date.month
        @day = date.day
      else
        month_zero_padded

        if @reader.peek_next_char.ascii_number? || !current_char.ascii_number?
          # calendar date
          extended_format ? char('-') : char?('-')

          day_of_month_zero_padded
        else
          # ordinal date
          day_of_the_year = @month * 10 + current_char.to_i
          next_char

          date = Time.utc(@year, 1, 1) + (day_of_the_year - 1).days
          @month = date.month
          @day = date.day
        end
      end
    end

    def hour_minute_second_iso8601
      hour_24_zero_padded
      decimal_seconds = Time::SECONDS_PER_HOUR

      extended_format = char? ':'

      if current_char.ascii_number?
        minute
        decimal_seconds = Time::SECONDS_PER_MINUTE

        has_colon = char?(':')

        if current_char.ascii_number?
          if extended_format && !has_colon
            raise "Unexpected char: #{current_char.inspect} (#{@reader.pos})"
          end

          second

          if current_char == '.' || current_char == ','
            next_char
            second_fraction
          end

          return
        end
      end

      if current_char == '.' || current_char == ','
        next_char

        pos = @reader.pos
        # Consume at most 12 digits as i64
        decimals = consume_number_i64(12)

        digits = @reader.pos - pos
        if digits > 6
          # make sure to avoid overflow
          decimals = decimals / 10_i64 ** (digits - 6)
          digits = 6
        end

        @nanosecond_offset = decimals.to_i64 * 10 ** 9 / 10 ** digits * decimal_seconds
      end
    end
  end

  struct Formatter
    def year_month_day_iso_8601
      year_month_day
    end

    def hour_minute_second_iso8601
      twenty_four_hour_time_with_seconds
    end
  end

  # The ISO 8601 date format.
  module ISO_8601_DATE
    # Parses a string into a `Time`.
    def self.parse(string, location : Time::Location? = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.year_month_day_iso_8601
      parser.time(location)
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time, io)
      formatter.year_month_day_iso_8601
      io
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time)
      String.build do |io|
        format(time, io)
      end
    end
  end

  # The ISO 8601 date time format.
  module ISO_8601_DATE_TIME
    # Parses a string into a `Time`.
    def self.parse(string, location : Time::Location? = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.date_time_iso_8601
      parser.time(location)
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time, io)
      formatter.rfc_3339
      io
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time)
      String.build do |io|
        format(time, io)
      end
    end
  end

  # The ISO 8601 time format.
  module ISO_8601_TIME
    # Parses a string into a `Time`.
    def self.parse(string, location : Time::Location? = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.time_iso_8601
      parser.time(location)
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO)
      formatter = Formatter.new(time, io)
      formatter.time_iso_8601
      io
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time)
      String.build do |io|
        format(time, io)
      end
    end
  end
end
