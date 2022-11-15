struct Time::Format
  module Pattern
    def date_time_iso_8601 : Nil
      year_month_day_iso_8601
      char? 'T'
      time_iso_8601
    end

    def time_iso_8601 : Nil
      hour_minute_second_iso8601
      time_zone_z_or_offset
    end
  end

  struct Parser
    def year_month_day_iso_8601 : Nil
      year
      extended_format = char? '-'
      if current_char == 'W'
        # week date
        next_char

        week = consume_number(2)
        extended_format ? char('-') : char?('-')

        day_of_week = consume_number(1)

        date = Time.week_date(@year, week, day_of_week, location: Time::Location::UTC)

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
          @month = 0
          next_char
          days_per_month = Time.leap_year?(@year) ? Time::DAYS_MONTH_LEAP : Time::DAYS_MONTH

          days_per_month.each_with_index do |days, month|
            if day_of_the_year > days
              day_of_the_year -= days
            else
              @day = day_of_the_year
              @month = month
              break
            end
          end
        end
      end
    end

    def hour_minute_second_iso8601 : Nil
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

          if current_char.in?('.', ',')
            next_char
            second_fraction
          end

          return
        end
      end

      if current_char.in?('.', ',')
        next_char

        pos = @reader.pos
        # Consume at most 12 digits as i64
        decimals = consume_number_i64(12)

        digits = @reader.pos - pos
        if digits > 6
          # make sure to avoid overflow
          decimals = decimals // 10_i64 ** (digits - 6)
          digits = 6
        end

        @nanosecond_offset = decimals.to_i64 * 10 ** 9 // 10 ** digits * decimal_seconds
      end
    end
  end

  struct Formatter
    def year_month_day_iso_8601 : Nil
      year_month_day
    end

    def hour_minute_second_iso8601
      twenty_four_hour_time_with_seconds
    end
  end

  # The ISO 8601 date format.
  #
  # ```
  # Time::Format::ISO_8601_DATE.parse("2016-02-15")                      # => 2016-02-15 00:00:00.0 UTC
  # Time::Format::ISO_8601_DATE.format(Time.utc(2016, 2, 15, 4, 35, 50)) # => "2016-02-15"
  # ```
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
    def self.format(time : Time) : String
      String.build do |io|
        format(time, io)
      end
    end
  end

  # The ISO 8601 date time format.
  #
  # ```
  # Time::Format::ISO_8601_DATE_TIME.format(Time.utc(2016, 2, 15, 4, 35, 50)) # => "2016-02-15T04:35:50Z"
  # Time::Format::ISO_8601_DATE_TIME.parse("2016-02-15T04:35:50Z")            # => 2016-02-15 04:35:50.0 UTC
  # ```
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
    def self.format(time : Time) : String
      String.build do |io|
        format(time, io)
      end
    end
  end

  # The ISO 8601 time format.
  #
  # ```
  # Time::Format::ISO_8601_TIME.format(Time.utc(2016, 2, 15, 4, 35, 50)) # => "04:35:50Z"
  # Time::Format::ISO_8601_TIME.parse("04:35:50Z")                       # => 0001-01-01 04:35:50.0 UTC
  # ```
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
