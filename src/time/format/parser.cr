struct Time::Format
  # :nodoc:
  struct Parser
    include Pattern

    @epoch : Int64?

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
    end

    def time(kind = Time::Kind::Unspecified)
      @hour += 12 if @pm

      time_kind = @kind || kind

      if epoch = @epoch
        return Time.epoch(epoch)
      end

      time = Time.new @year, @month, @day, @hour, @minute, @second, nanosecond: @nanosecond, kind: time_kind

      if offset_in_minutes = @offset_in_minutes
        time -= offset_in_minutes.minutes if offset_in_minutes != 0

        if (offset_in_minutes != 0) || (kind == Time::Kind::Local && !time.local?)
          time = time.to_local
        end
      end

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
      month_name
    end

    def short_month_name_upcase
      month_name
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

    def day_of_year_zero_padded
      # TODO
      consume_number(3)
    end

    def hour_24_zero_padded
      @hour = consume_number(2)
    end

    def hour_24_blank_padded
      @hour = consume_number_blank_padded(2)
    end

    def hour_12_zero_padded
      hour_24_zero_padded
    end

    def hour_12_blank_padded
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

    def am_pm
      string = consume_string
      case string.downcase
      when "am"
        # skip
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
      consume_number(1)
    end

    def day_of_week_sunday_0_6
      consume_number(1)
    end

    def epoch
      epoch_negative = false
      case current_char
      when '-'
        epoch_negative = true
        next_char
      when '+'
        next_char
      end

      @epoch = consume_number_i64(19) * (epoch_negative ? -1 : 1)
    end

    def time_zone
      case char = current_char
      when 'Z'
        @offset_in_minutes = 0
        @kind = Time::Kind::Utc
        next_char
      when 'U'
        if next_char == 'T' && next_char == 'C'
          @offset_in_minutes = 0
          @kind = Time::Kind::Utc
          next_char
        else
          raise "Invalid timezone"
        end
      when '-', '+'
        sign = char == '-' ? -1 : 1

        char = next_char
        raise "Invalid timezone" unless char.ascii_number?
        hours = char.to_i

        char = next_char
        raise "Invalid timezone" unless char.ascii_number?
        hours = 10*hours + char.to_i

        char = next_char
        char = next_char if char == ':'
        raise "Invalid timezone" unless char.ascii_number?
        minutes = char.to_i

        char = next_char
        raise "Invalid timezone" unless char.ascii_number?
        minutes = 10*minutes + char.to_i

        @offset_in_minutes = sign * (60*hours + minutes)
        @kind = Time::Kind::Utc
        char = next_char

        if @reader.has_next?
          pos = @reader.pos
          if char == ':' && next_char.ascii_number? && @reader.has_next? && next_char.ascii_number?
            next_char
          elsif char.ascii_number? && next_char.ascii_number?
            next_char
          else
            @reader.pos = pos
          end
        end
      end
    end

    def time_zone_colon
      time_zone
    end

    def time_zone_colon_with_seconds
      time_zone
    end

    def char(char)
      if current_char == char
        next_char
      else
        raise "Unexpected char: #{char.inspect} (#{@reader.pos})"
      end
    end

    def consume_number(max_digits)
      consume_number_i64(max_digits).to_i
    end

    def consume_number_i64(max_digits)
      n = 0_i64
      char = current_char

      if char.ascii_number?
        n = (char - '0').to_i64
        char = next_char
      else
        raise "Expecting number"
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

    def current_char
      @reader.current_char
    end

    def next_char
      @reader.next_char
    end

    def raise(message)
      ::raise Error.new(message)
    end
  end
end
