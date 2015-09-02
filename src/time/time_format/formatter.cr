require "./pattern"

struct TimeFormat
  # :nodoc:
  struct Formatter
    include Pattern

    getter io
    getter time

    def initialize(@time, @io)
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
      pad2 (time.hour % 12), '0'
    end

    def hour_12_blank_padded
      pad2 (time.hour % 12), ' '
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

    # Internal helper wethod: Figure how many weeks into the year
    private def week_of_year(time: Time, firstweekday: Number) : Number
      day_of_week = time.day_of_week.value
      day_of_week = 7 if day_of_week == 0
      week_num = 0

      if firstweekday == 1
        if day_of_week == 0 # sunday
          day_of_week = 6
        else
          day_of_week -= 1
        end
      end

      week_num = ((time.day_of_year + 7 - day_of_week) / 7)
      week_num = 0 if week_num < 0

      week_num
    end

    # Compute week number according to ISO 8601
    private def iso8601_week_of_year_internal(time: Time) : Number
      #	If the week (Monday to Sunday) containing January 1
      #	has four or more days in the new year, then it is week 1;
      #	otherwise it is the highest numbered week of the previous
      #	year (52 or 53), and the next week is week 1.

      weeknum = 0

      # Get week number
      weeknum = week_of_year(time, 1)

      # What day of the week does January 1 fall on?
      day_of_week = time.day_of_week.value
      day_of_week = 7 if day_of_week == 0

      jan1day = day_of_week - (time.day_of_year % 7)
      jan1day += 7 if jan1day < 0

      # If Jan 1 was a Monday through Thursday, it was in
      # week 1.  Otherwise it was last year's highest week, which is this year's week 0.
      #
      # What does that mean?
      # If Jan 1 was Monday, the week number is exactly right, it can never be 0.
      # If it was Tuesday through Thursday, the weeknumber is one less than it should be, so we add one.
      # Otherwise, Friday, Saturday or Sunday, the week number is
      # OK, but if it is 0, it needs to be 52 or 53.

      case jan1day
      when 1 # Monday
        # nothing

      when 2, 3, 4 # Tuesday, Wednesday, Thursday
        weeknum += 1

      when 5, 6, 0 # Friday, Saturday, Sunday
        if weeknum == 0
          # get week number of last week of last year
          weeknum = iso8601_week_of_year_internal(Time.new(time.year - 1, 12, 31))
        end
      end

      if time.month == 11
        # The last week of the year
        # can be in week 1 of next year.
        # Sigh.
        #
        # This can only happen if
        #	M   T   W
        #	29  30  31
        #	30  31
        #	31

        wday = time.day_of_week.value
        wday = 7 if wday == 0
        mday = time.day

        if (wday == 1 && (mday >= 29 && mday <= 31)) || (wday == 2 && (mday == 30 || mday == 31)) || (wday == 3 &&  mday == 31)
          weeknum = 1
        end
      end

      weeknum
    end

    # Compute week of the year, monday is the first day of the week
    def week_of_year_monday_1_7
      io << week_of_year(time, 1)
    end

    # Compute week of the year, sunday is the first day of the week
    def week_of_year_sunday_0_6
      io << week_of_year(time, 0)
    end

    # Compute week of the year according to ISO8601
    def iso8601_week_of_year
      io << iso8601_week_of_year_internal(time)
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
