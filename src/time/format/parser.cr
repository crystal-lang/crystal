struct Time::Format
  # :nodoc:
  struct Parser
    include Pattern

    # :nodoc:
    RFC_2822_LOCATIONS = {
      "UT"  => Location::UTC,
      "GMT" => Location::UTC,
      "EST" => Location.fixed("EST", -5 * 3600),
      "EDT" => Location.fixed("EDT", -4 * 3600),
      "CST" => Location.fixed("CST", -6 * 3600),
      "CDT" => Location.fixed("CDT", -5 * 3600),
      "MST" => Location.fixed("MST", -7 * 3600),
      "MDT" => Location.fixed("MDT", -6 * 3600),
      "PST" => Location.fixed("PST", -8 * 3600),
      "PDT" => Location.fixed("PDT", -7 * 3600),
    }

    @unix_seconds : Int64?
    @location : Location?
    @calendar_week_week : Int32?
    @calendar_week_year : Int32?
    @day_of_week : Time::DayOfWeek?
    @day_of_year : Int32?

    def initialize(string)
      @reader = Char::Reader.new(string)
      @year = 1
      @month = 1
      @day = 1
      @hour = 0
      @minute = 0
      @second = 0
      @nanosecond = 0
      @pm = false
      @hour_is_12 = false
      @nanosecond_offset = 0_i64
    end

    def time(location : Location? = nil) : Time
      if @hour_is_12
        if @hour > 12
          raise ArgumentError.new("Invalid hour for 12-hour clock")
        end

        if @pm
          @hour += 12 unless @hour == 12
        else
          if @hour == 0
            raise ArgumentError.new("Invalid hour for 12-hour clock")
          end

          @hour = 0 if @hour == 12
        end
      end

      if unix_seconds = @unix_seconds
        return Time.unix(unix_seconds)
      end

      location = @location || location
      if location.nil?
        raise "Time format did not include time zone and no default location provided", pos: false
      end

      if (calendar_week_week = @calendar_week_week) && (calendar_week_year = @calendar_week_year) && (day_of_week = @day_of_week)
        # If all components of a week date are available, they are used to create a Time instance
        time = Time.week_date calendar_week_year, calendar_week_week, day_of_week, @hour, @minute, @second, nanosecond: @nanosecond, location: location
      else
        if day_of_year = @day_of_year
          raise "Invalid day of year" unless day_of_year.in?(1..Time.days_in_year(@year))
          days_per_month = Time.leap_year?(@year) ? DAYS_MONTH_LEAP : DAYS_MONTH
          month = 1
          day = day_of_year
          while day > days_per_month[month]
            day -= days_per_month[month]
            month += 1
          end
        else
          month = @month
          day = @day
        end
        time = Time.local @year, month, day, @hour, @minute, @second, nanosecond: @nanosecond, location: location
      end

      time = time.shift 0, @nanosecond_offset

      time
    end

    def year
      @year = consume_number(4)
    end

    def year_modulo_100
      year = consume_number(2)
      if 69 <= year <= 99
        @year = year + 1900
      elsif 0 <= year
        @year = year + 2000
      else
        raise "Invalid year"
      end
    end

    def year_divided_by_100
      @year = consume_number(2) * 100
    end

    def full_or_short_year
      @year = case year = consume_number(4)
              when 0..49
                year + 2000
              when 50..999
                year + 1900
              else
                year
              end
    end

    def calendar_week_year
      @calendar_week_year = consume_number(4)
    end

    def calendar_week_year_modulo100
      @calendar_week_year = consume_number(2)
    end

    def month
      @month = consume_number(2)
    end

    def month_zero_padded
      month
    end

    def month_blank_padded
      @month = consume_number_blank_padded(2)
    end

    def month_name
      string = consume_string
      if string.size < 3
        raise "Invalid month"
      end

      string = string.capitalize
      index = MONTH_NAMES.index &.starts_with?(string)
      if index
        @month = 1 + index
      else
        raise "Invalid month"
      end
    end

    def month_name_upcase
      month_name
    end

    def short_month_name
      string = consume_string
      if string.size != 3
        raise "Invalid month"
      end

      string = string.capitalize
      index = MONTH_NAMES.index &.starts_with?(string)
      if index
        @month = 1 + index
      else
        raise "Invalid month"
      end
    end

    def short_month_name_upcase
      month_name
    end

    def calendar_week_week
      @calendar_week_week = consume_number(2)
    end

    def day_of_month
      @day = consume_number(2)
    end

    def day_of_month_zero_padded
      @day = consume_number(2)
    end

    def day_of_month_blank_padded
      @day = consume_number_blank_padded(2)
    end

    def day_name
      string = consume_string
      if string.size < 3
        raise "Invalid day name"
      end

      string = string.capitalize
      index = DAY_NAMES.index &.starts_with?(string)
      unless index
        raise "Invalid day name"
      end
    end

    def day_name_upcase
      day_name
    end

    def short_day_name
      day_name
    end

    def short_day_name_upcase
      day_name
    end

    def short_day_name_with_comma?
      return unless current_char.ascii_letter?

      short_day_name
      char ','
      whitespace
    end

    def day_of_year_zero_padded
      @day_of_year = consume_number(3)
    end

    def hour_24_zero_padded
      @hour_is_12 = false
      @hour = consume_number(2)
    end

    def hour_24_blank_padded
      @hour_is_12 = false
      @hour = consume_number_blank_padded(2)
    end

    def hour_12_zero_padded
      hour_24_zero_padded
      @hour_is_12 = true
    end

    def hour_12_blank_padded
      @hour_is_12 = true
      @hour = consume_number_blank_padded(2)
    end

    def minute
      @minute = consume_number(2)
    end

    def second
      @second = consume_number(2)
    end

    def milliseconds
      second_decimals 3
    end

    def microseconds
      second_decimals 6
    end

    def nanoseconds
      second_decimals 9
    end

    def second_fraction
      second_decimals 9
      # consume trailing numbers
      while current_char.ascii_number?
        next_char
      end
    end

    private def second_decimals(precision)
      pos = @reader.pos
      # Consume at most *precision* digits as i64
      decimals = consume_number_i64(precision)
      # Multiply the parsed value if does not match the expected precision
      digits = @reader.pos - pos
      precision_shift = digits < precision ? precision - digits : 0
      # Adjust to nanoseconds
      nanoseconds_shift = 9 - precision
      @nanosecond = (decimals * 10 ** (precision_shift + nanoseconds_shift)).to_i
    end

    def second_fraction?(fraction_digits = nil)
      if current_char == '.'
        next_char
        nanoseconds
      end
    end

    def am_pm
      string = consume_string
      case string.downcase
      when "am"
        @pm = false
      when "pm"
        @pm = true
      else
        raise "Invalid am/pm"
      end
    end

    def am_pm_upcase
      am_pm
    end

    def day_of_week_monday_1_7
      @day_of_week = Time::DayOfWeek.from_value(consume_number(1))
    end

    def day_of_week_sunday_0_6
      @day_of_week = Time::DayOfWeek.from_value(consume_number(1))
    end

    def unix_seconds
      negative = false
      case current_char
      when '-'
        negative = true
        next_char
      when '+'
        next_char
      else
        # no sign prefix
      end

      @unix_seconds = consume_number_i64(19) * (negative ? -1 : 1)
    end

    def time_zone(with_seconds = false)
      case current_char
      when 'Z'
        time_zone_z
      when 'U'
        if next_char == 'T' && next_char == 'C'
          @location = Location::UTC
          next_char
        else
          raise "Invalid timezone"
        end
      when '-', '+'
        time_zone_offset
      else
        raise "Invalid timezone"
      end
    end

    def time_zone_z_or_offset(**options)
      case current_char
      when 'Z', 'z'
        time_zone_z
      when '-', '+'
        time_zone_offset(**options)
      else
        raise "Invalid timezone"
      end
    end

    def time_zone_z
      raise "Invalid timezone" unless current_char.in?('Z', 'z')

      @location = Location::UTC
      next_char
    end

    def time_zone_offset(force_colon = false, allow_colon = true, format_seconds = false, parse_seconds = true, force_zero_padding = true, force_minutes = true)
      case current_char
      when '-'
        sign = -1
      when '+'
        sign = 1
      else
        raise "Invalid timezone"
      end

      char = next_char
      raise "Invalid timezone" unless char.ascii_number?
      hours = char.to_i

      char = next_char
      if char.ascii_number?
        hours = hours * 10 + char.to_i

        char = next_char
      elsif force_zero_padding
        raise "Invalid timezone"
      end

      if char == ':'
        raise "Invalid timezone" unless allow_colon
        char = next_char
      elsif force_colon
        raise "Invalid timezone"
      end

      if char.ascii_number?
        minutes = char.to_i

        char = next_char
        if char.ascii_number?
          minutes = minutes * 10 + char.to_i

          char = next_char
        elsif force_zero_padding
          raise "Invalid timezone"
        end
      elsif force_minutes
        raise "Invalid timezone"
      else
        minutes = 0
      end

      seconds = 0
      if @reader.has_next? && parse_seconds
        pos = @reader.pos
        if char == ':'
          char = next_char
          raise "Invalid timezone" unless char.ascii_number?
        elsif force_colon && char.ascii_number?
          raise "Invalid timezone"
        end

        if char.ascii_number?
          seconds = char.to_i

          char = next_char
          raise "Invalid timezone" unless char.ascii_number?
          seconds = seconds * 10 + char.to_i

          next_char
        else
          @reader.pos = pos
        end
      end

      @location = Location.fixed(sign * (3600 * hours + 60 * minutes + seconds))
    end

    def time_zone_colon
      time_zone
    end

    def time_zone_colon_with_seconds
      time_zone(with_seconds: true)
    end

    def time_zone_gmt
      consume_string == "GMT" || raise "Invalid timezone"
      @location = Location::UTC
    end

    def time_zone_rfc2822
      case current_char
      when '-', '+'
        time_zone_offset(allow_colon: false)
      else
        zone = consume_string

        @location = RFC_2822_LOCATIONS.fetch(zone, Location::UTC)
      end
    end

    def time_zone_gmt_or_rfc2822(**options)
      time_zone_rfc2822
    end

    def time_zone_name(zone = false)
      case current_char
      when '-', '+'
        time_zone_offset
      else
        start_pos = @reader.pos
        while @reader.has_next? && (!current_char.whitespace? || current_char == Char::ZERO)
          next_char
        end
        zone_name = @reader.string.byte_slice(start_pos, @reader.pos - start_pos)

        if zone_name.in?("Z", "UTC")
          @location = Time::Location::UTC
        else
          @location = Time::Location.load(zone_name)
        end
      end
    end

    def char?(char, *alternatives)
      if current_char == char || alternatives.includes?(current_char)
        next_char
        true
      else
        false
      end
    end

    def char(char, *alternatives)
      unless @reader.has_next?
        if alternatives.empty?
          raise "Expected #{char.inspect} but the end of the input was reached"
        else
          raise "Expected one of #{char.inspect}, #{alternatives.join(", ", &.inspect)} but reached the input end"
        end
      end

      unless char?(char, *alternatives)
        raise "Unexpected char: #{current_char.inspect}"
      end
    end

    def consume_number(max_digits)
      consume_number_i64(max_digits).to_i
    end

    def consume_number?(max_digits)
      consume_number_i64?(max_digits).try(&.to_i)
    end

    def consume_number_i64(max_digits)
      consume_number_i64?(max_digits) || raise "Invalid number"
    end

    def consume_number_i64?(max_digits)
      n = 0_i64
      char = current_char

      if char.ascii_number?
        n = (char - '0').to_i64
        char = next_char
      else
        return nil
      end

      max_digits -= 1

      while max_digits > 0 && char.ascii_number?
        n = n * 10 + (char - '0')
        char = next_char
        max_digits -= 1
      end

      n
    end

    def consume_number_blank_padded(max_digits)
      if current_char.ascii_whitespace?
        max_digits -= 1
        next_char
      end

      consume_number(max_digits)
    end

    def consume_string
      start_pos = @reader.pos
      while current_char.ascii_letter?
        next_char
      end
      @reader.string.byte_slice(start_pos, @reader.pos - start_pos)
    end

    def skip_space
      next_char if current_char.ascii_whitespace?
    end

    def skip_spaces
      while current_char.ascii_whitespace?
        next_char
      end
    end

    def whitespace
      unless current_char.ascii_whitespace?
        ::raise "Unexpected char: #{current_char.inspect}"
      end
      next_char
    end

    def current_char
      @reader.current_char
    end

    def next_char
      @reader.next_char
    end

    def raise(message, pos = @reader.pos)
      string = @reader.string
      if pos.is_a?(Int)
        string = "#{string.byte_slice(0, pos)}>>#{string.byte_slice(pos, string.bytesize - pos)}"
        ::raise Error.new("#{message} at #{@reader.pos}: #{string.inspect}")
      else
        ::raise Error.new("#{message}: #{string.inspect}")
      end
    end
  end
end
