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

    def full_or_short_year
      year
    end

    def calendar_week_year
      pad4(time.calendar_week[0], '0')
    end

    def calendar_week_year_modulo100
      pad2(time.calendar_week[0] % 100, '0')
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

    def calendar_week_week
      pad2(time.calendar_week[1], '0')
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

    def short_day_name_with_comma?
      short_day_name
      char ','
      whitespace
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

    def microseconds
      pad6 time.nanosecond / 1000, '0'
    end

    def nanoseconds
      pad9 time.nanosecond, '0'
    end

    def second_fraction
      nanoseconds
    end

    def second_fraction?(fraction_digits = nil)
      unless time.nanosecond == 0 || fraction_digits == 0
        char '.'
        second_fraction
      end
    end

    def am_pm
      io << (time.hour < 12 ? "am" : "pm")
    end

    def am_pm_upcase
      io << (time.hour < 12 ? "AM" : "PM")
    end

    def day_of_week_monday_1_7
      io << time.day_of_week.value
    end

    def day_of_week_sunday_0_6
      io << time.day_of_week.value % 7
    end

    def unix_seconds
      io << time.to_unix
    end

    def time_zone(with_seconds = false)
      time_zone_offset(allow_seconds: with_seconds)
    end

    def time_zone_z_or_offset(**options)
      if time.utc?
        io << 'Z'
      else
        time_zone_offset(**options)
      end
    end

    def time_zone_offset(force_colon = false, allow_colon = true, allow_seconds = true)
      time.zone.format(io, with_colon: force_colon, with_seconds: allow_seconds)
    end

    def time_zone_colon(with_seconds = false)
      time_zone_offset(force_colon: true, allow_seconds: with_seconds)
    end

    def time_zone_colon_with_seconds
      time_zone_colon(with_seconds: true)
    end

    def time_zone_gmt
      io << "GMT"
    end

    def time_zone_rfc2822
      time_zone_offset(allow_colon: false, allow_seconds: false)
    end

    def time_zone_gmt_or_rfc2822(**options)
      if time.utc? || time.location.name == "UT" || time.location.name == "GMT"
        time_zone_gmt
      else
        time_zone_rfc2822
      end
    end

    def char(char, *alternatives)
      io << char
    end

    def char?(char, *alternatives)
      char(char, *alternatives)
    end

    def whitespace
      io << ' '
    end

    def get_month_name
      MONTH_NAMES[time.month - 1]
    end

    def get_short_month_name
      get_month_name[0, 3]
    end

    def get_day_name
      DAY_NAMES[time.day_of_week.value % 7]
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

    def pad6(value, padding)
      io.write_byte padding.ord.to_u8 if value < 100000
      io.write_byte padding.ord.to_u8 if value < 10000
      pad4 value, padding
    end

    def pad9(value, padding)
      io.write_byte padding.ord.to_u8 if value < 100000000
      io.write_byte padding.ord.to_u8 if value < 10000000
      io.write_byte padding.ord.to_u8 if value < 1000000
      pad6 value, padding
    end
  end
end
