module Time::Format
  # :nodoc:
  module ISO_8601
    # :nodoc:
    module Parser
      def year_month_day_iso_8601
        year
        extended_format = char? '-'
        if current_char == 'W'
          # week date
          # TODO: Add support for week day (needs mapping between year and week day)
          week = consume_number(2)
          char '-', raise: extended_format
          day_of_the_week = consume_number(1)

          raise "week date not yet supported"
          return
        end
        month_zero_padded

        if @reader.peek_next_char.ascii_number? || !current_char.ascii_number?
          # calendar date
          char '-', raise: extended_format
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

      def hour_minute_second_iso8601
        hour_24_zero_padded
        decimal_seconds = Time::SECONDS_PER_HOUR

        extended_format = char? ':'

        if current_char.ascii_number?
          minute
          decimal_seconds = Time::SECONDS_PER_MINUTE

          char ':', raise: extended_format && current_char.ascii_number?
          if current_char.ascii_number?
            second
            decimal_seconds = 1
          end
        end

        if current_char == '.' || current_char == ','
          decimal = consume_number_i64(12) * decimal_seconds
          # TODO: implement parser for decimal fractions
        end
      end
    end

    # :nodoc:
    module Formatter
      def year_month_day_iso_8601
        year_month_day
      end

      def hour_minute_second_iso8601
        twenty_four_hour_time_with_seconds
      end
    end
  end

  # The ISO 8601 date format.
  module ISO_8601_DATE
    extend Format

    # :nodoc:
    module Visitor
      def visit
        year_month_day_iso_8601
      end
    end

    struct Parser
      include ISO_8601::Parser
    end

    struct Formatter
      include ISO_8601::Formatter
    end
  end

  # The ISO 8601 date time format.
  module ISO_8601_DATE_TIME
    extend Format

    # :nodoc:
    module Visitor
      def visit
        year_month_day_iso_8601
        char? 'T'
        hour_minute_second_iso8601
        time_zone_z_or_offset
      end
    end

    struct Parser
      include ISO_8601::Parser
    end

    struct Formatter
      include ISO_8601::Formatter
    end
  end

  # The ISO 8601 time format.
  module ISO_8601_TIME
    extend Format

    # :nodoc:
    module Visitor
      def visit
        hour_minute_second_iso8601
        time_zone_z_or_offset
      end
    end

    struct Parser
      include ISO_8601::Parser
    end

    struct Formatter
      include ISO_8601::Formatter
    end
  end
end
