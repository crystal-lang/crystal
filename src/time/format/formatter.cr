require "./pattern"

struct Time::Format
  # :nodoc:
  struct Formatter
    include Pattern

    getter io : IO
    getter time : Time

    def initialize(@time : Time, @io : IO)
    end

    def year
      pad4(time.year, '0')
    end

    def year_modulo_100
      pad2(time.year % 100, '0')
    end

    def year_divided_by_100
      io << time.year / 100
    end

    def month
      io << time.month
    end

    def month_zero_padded
      pad2 time.month, '0'
    end

    def month_blank_padded
      pad2 time.month, ' '
    end

    def month_name
      io << get_month_name
    end

    def month_name_upcase
      io << get_month_name.upcase
    end

    def short_month_name
      io << get_short_month_name
    end

    def short_month_name_upcase
      io << get_short_month_name.upcase
    end

    def day_of_month
      io << time.day
    end

    def day_of_month_zero_padded
      pad2 time.day, '0'
    end

    def day_of_month_blank_padded
      pad2 time.day, ' '
    end

    def day_name
      io << get_day_name
    end

    def day_name_upcase
      io << get_day_name.upcase
    end

    def short_day_name
      io << get_short_day_name
    end

    def short_day_name_upcase
      io << get_short_day_name.upcase
    end

    def day_of_year_zero_padded
      pad3 time.day_of_year, '0'
    end

    def hour_24_zero_padded
      pad2 time.hour, '0'
    end

    def hour_24_blank_padded
      pad2 time.hour, ' '
    end

    def hour_12_zero_padded
      h = (time.hour % 12)
      pad2 (h == 0 ? 12 : h), '0'
    end

    def hour_12_blank_padded
      h = (time.hour % 12)
      pad2 (h == 0 ? 12 : h), ' '
    end

    def minute
      pad2 time.minute, '0'
    end

    def second
      pad2 time.second, '0'
    end

    def milliseconds
      pad3 time.millisecond, '0'
    end

    def am_pm
      io << (time.hour < 12 ? "am" : "pm")
    end

    def am_pm_upcase
      io << (time.hour < 12 ? "AM" : "PM")
    end

    def day_of_week_monday_1_7
      v = time.day_of_week.value
      v = 7 if v == 0
      io << v
    end

    def day_of_week_sunday_0_6
      io << time.day_of_week.value
    end

    def epoch
      io << time.epoch
    end

    def time_zone
      case time.kind
      when Time::Kind::Utc, Time::Kind::Unspecified
        io << "+0000"
      when Time::Kind::Local
        negative, hours, minutes = local_time_zone_info
        io << (negative ? "-" : "+")
        io << "0" if hours < 10
        io << hours
        io << "0" if minutes < 10
        io << minutes
      end
    end

    def time_zone_colon
      case time.kind
      when Time::Kind::Utc, Time::Kind::Unspecified
        io << "+00:00"
      when Time::Kind::Local
        negative, hours, minutes = local_time_zone_info
        io << (negative ? "-" : "+")
        io << "0" if hours < 10
        io << hours
        io << ":"
        io << "0" if minutes < 10
        io << minutes
      end
    end

    def time_zone_colon_with_seconds
      time_zone_colon
      io << ":00"
    end

    def local_time_zone_info
      minutes = Time.local_offset_in_minutes
      if minutes < 0
        minutes = -minutes
        negative = true
      else
        negative = false
      end
      hours = minutes / 60
      minutes = minutes % 60
      {negative, hours, minutes}
    end

    def char(char)
      io << char
    end

    def get_month_name
      MONTH_NAMES[time.month - 1]
    end

    def get_short_month_name
      get_month_name[0, 3]
    end

    def get_day_name
      DAY_NAMES[time.day_of_week.value]
    end

    def get_short_day_name
      get_day_name[0, 3]
    end

    def pad2(value, padding)
      io.write_byte padding.ord.to_u8 if value < 10
      io << value
    end

    def pad3(value, padding)
      io.write_byte padding.ord.to_u8 if value < 100
      pad2 value, padding
    end

    def pad4(value, padding)
      io.write_byte padding.ord.to_u8 if value < 1000
      pad3 value, padding
    end
  end
end
