struct TimeFormat
  module Pattern
    MONTH_NAMES = %w(January February March April May June July August September October November December)
    DAY_NAMES = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

    def visit(pattern)
      i = 0
      bytesize = pattern.bytesize
      str = pattern.cstr

      while i < bytesize
        byte = str[i]
        case byte.chr
        when '%'
          i += 1
          byte = str[i]
          case byte.chr
          when 'a'
            short_day_name
          when 'A'
            day_name
          when 'b', 'h'
            short_month_name
          when 'c'
            date_and_time
          when 'B'
            month_name
          when 'C'
            year_divided_by_100
          when 'd'
            day_of_month_zero_padded
          when 'D', 'x'
            date
          when 'e'
            day_of_month_blank_padded
          when 'F'
            iso_8601_date
          when 'j'
            day_of_year_zero_padded
          when 'H'
            hour_24_zero_padded
          when 'I'
            hour_12_zero_padded
          when 'k'
            hour_24_blank_padded
          when 'l'
            hour_12_blank_padded
          when 'L'
            milliseconds
          when 'm'
            month_zero_padded
          when 'M'
            minute_zero_padded
          when 'p'
            am_pm
          when 'P'
            am_pm_upcase
          when 'r'
            twelve_hour_time
          when 'R'
            twenty_four_hour_time
          when 'S'
            second_zero_padded
          when 'T'
            twenty_four_hour_time_with_seconds
          when 'u'
            day_of_week_monday_1_7
          when 'w'
            day_of_week_sunday_0_6
          when 'X'
            twenty_four_hour_time_with_seconds
          when 'y'
            year_modulo_100
          when 'Y'
            year
          when '_'
            i += 1
            byte = str[i]
            case byte.chr
            when 'm'
              month_blank_padded
            else
              char '%'
              char '_'
              byte byte
            end
          when '-'
            i += 1
            byte = str[i]
            case byte.chr
            when 'd'
              day
            when 'm'
              month
            else
              char '%'
              char '-'
              byte byte
            end
          when '^'
            i += 1
            byte = str[i]
            case byte.chr
            when 'A'
              day_name_upcase
            when 'b', 'h'
              short_month_name_upcase
            when 'B'
              month_name_upcase
            else
              char '%'
              char '^'
              byte byte
            end
          when '%'
            char '%'
          else
            char '%'
            byte byte
          end
        else
          byte byte
        end

        i += 1
      end
    end

    def char(char)
      byte char.ord.to_u8
    end

    def date_and_time
      short_day_name
      char ' '
      short_month_name
      char ' '
      day_of_month_blank_padded
      char ' '
      twenty_four_hour_time_with_seconds
      char ' '
      year
    end

    def date
      month_zero_padded
      char '/'
      day_of_month_zero_padded
      char '/'
      year_modulo_100
    end

    def iso_8601_date
      year
      char '-'
      month_zero_padded
      char '-'
      day_of_month_zero_padded
    end

    def twelve_hour_time
      hour_12_zero_padded
      char ':'
      minute_zero_padded
      char ':'
      second_zero_padded
      char ' '
      am_pm_upcase
    end

    def twenty_four_hour_time
      hour_24_zero_padded
      char ':'
      minute_zero_padded
    end

    def twenty_four_hour_time_with_seconds
      hour_24_zero_padded
      char ':'
      minute_zero_padded
      char ':'
      second_zero_padded
    end
  end
end
