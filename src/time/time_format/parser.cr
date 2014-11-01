struct TimeFormat
  struct Parser
    include Pattern

    def initialize(string)
      @reader = CharReader.new(string)
      @year = 1
      @month = 1
      @day = 1
      @hour = 0
      @minute = 0
      @second = 0
      @millisecond = 0
      @pm = false
    end

    def time
      @hour += 12 if @pm
      Time.new @year, @month, @day, @hour, @minute, @second, @millisecond
    end

    def year
      @year = consume_number
    end

    def year_modulo_100
      year = consume_number
      if 69 <= year <= 99
        @year = year + 1900
      elsif 0 <= year
        @year = year + 2000
      else
        raise "invalid year"
      end
    end

    def year_divided_by_100
      @year = 100 * consume_number
    end

    def month
      @month = consume_number
    end

    def month_zero_padded
      month
    end

    def month_blank_padded
      skip_space
      month
    end

    def month_name
      string = consume_string
      if string.length < 3
        raise "invalid month"
      end

      string = string.capitalize
      index = MONTH_NAMES.index &.starts_with?(string)
      if index
        @month = index + 1
      else
        raise "invalid month"
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
      @day = consume_number
    end

    def day_of_month_zero_padded
      @day = consume_number
    end

    def day_of_month_blank_padded
      skip_space
      @day = consume_number
    end

    def day_name
      string = consume_string
      if string.length < 3
        raise "invalid day name"
      end

      string = string.capitalize
      index = DAY_NAMES.index &.starts_with?(string)
      unless index
        raise "invalid day name"
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
      @year = consume_number
    end

    def hour_24_zero_padded
      @hour = consume_number
    end

    def hour_24_blank_padded
      skip_space
      hour_24_zero_padded
    end

    def hour_12_zero_padded
      hour_24_zero_padded
    end

    def hour_12_blank_padded
      skip_space
      hour_24_zero_padded
    end

    def minute
      @minute = consume_number
    end

    def second
      @second = consume_number
    end

    def milliseconds
      @millisecond = consume_number
    end

    def am_pm
      string = consume_string
      case string.downcase
      when "am"
        # skip
      when "pm"
        @pm = true
      else
        raise "invalid am/pm"
      end
    end

    def am_pm_upcase
      am_pm
    end

    def day_of_week_monday_1_7
      consume_number
    end

    def day_of_week_sunday_0_6
      consume_number
    end

    def char(char)
      if current_char == char
        next_char
      else
        raise "unexpected char: #{char.inspect} (#{@reader.pos})"
      end
    end

    def byte(byte)
      char byte.chr
    end

    def consume_number
      n = 0
      char = current_char

      if char.digit?
        n = char - '0'
        char = next_char
      else
        raise "expecting number"
      end

      while char.digit?
        n = 10 * n + (char - '0')
        char = next_char
      end

      n
    end

    def consume_string
      start_pos = @reader.pos
      while current_char.alpha?
        next_char
      end
      @reader.string.byte_slice(start_pos, @reader.pos - start_pos)
    end

    def skip_space
      next_char if current_char.whitespace?
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
