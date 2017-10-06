require "./composite_terms"

module Time::Format
  # :nodoc:
  module Parser
    include CompositeTerms

    # :nodoc:
    RFC_2822_ZONES = {
      "UT"  => 0,
      "GMT" => 0,
      "EST" => -5,
      "EDT" => -4,
      "CST" => -6,
      "CDT" => -5,
      "MST" => -7,
      "MDT" => -6,
      "PST" => -8,
      "PDT" => -7,
    }

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
      case year = consume_number(2)
      when 69..99
        @year = year + 1900
      when .>(0)
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
      # Consume more than 3 digits (12 seems a good maximum),
      # and later just use the first 3 digits because Time
      # need millisecond precision.
      pos = @reader.pos
      millisecond = consume_number_i64(12)
      digits = @reader.pos - pos
      if digits > 3
        millisecond /= 10 ** (digits - 3)
      end
      @nanosecond = (millisecond * Time::NANOSECONDS_PER_MILLISECOND).to_i
    end

    def nanoseconds
      # Consume more than 9 digits (12 seems a good maximum),
      # and later just use the first 9 digits because Time
      # only has nanosecond precision.
      pos = @reader.pos
      nanosecond = consume_number(12)
      digits = @reader.pos - pos
      if digits > 9
        nanosecond /= 10 ** (digits - 9)
      end
      @nanosecond = nanosecond
    end

    def second_fraction?
      if current_char == '.'
        next_char
        milliseconds
      end
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
        time_zone_z
      when 'U'
        if next_char == 'T' && next_char == 'C'
          @offset_in_minutes = 0
          @kind = Time::Kind::Utc
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
      case char = current_char
      when 'Z', 'z'
        time_zone_z
      when '-', '+'
        time_zone_offset(**options)
      else
        raise "Invalid timezone: #{current_char.inspect} (#{@reader.pos}) #{self.inspect}"
      end
    end

    def time_zone_z
      raise "Invalid timezone" unless {'Z', 'z'}.includes? current_char

      @offset_in_minutes = 0
      @kind = Time::Kind::Utc
      next_char
    end

    def time_zone_offset(force_colon = false, allow_colon = true, allow_seconds = true)
      sign = current_char == '-' ? -1 : 1

      char = next_char
      raise "Invalid timezone" unless char.ascii_number?
      hours = char.to_i

      char = next_char
      raise "Invalid timezone" unless char.ascii_number?
      hours = 10*hours + char.to_i

      char = next_char
      if char == ':'
        raise "Invalid timezone" unless allow_colon
        char = next_char
      elsif force_colon
        raise "Invalid timezone"
      end
      raise "Invalid timezone" unless char.ascii_number?
      minutes = char.to_i

      char = next_char
      raise "Invalid timezone" unless char.ascii_number?
      minutes = 10*minutes + char.to_i

      @offset_in_minutes = sign * (60*hours + minutes)
      @kind = Time::Kind::Utc
      char = next_char

      if @reader.has_next? && allow_seconds
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

    def time_zone_colon
      time_zone
    end

    def time_zone_colon_with_seconds
      time_zone
    end

    def time_zone_gmt
      consume_string == "GMT" || raise "Invalid timezone"
      @kind = Time::Kind::Utc
      @offset_in_minutes = 0
    end

    def time_zone_rfc2822
      case char = current_char
      when '-', '+'
        time_zone_offset(allow_colon: false)
      else
        zone = consume_string
        @offset_in_minutes = (RFC_2822_ZONES[zone]? || 0) * 60
        @kind = Time::Kind::Utc
      end
    end

    def time_zone_gmt_or_rfc2822(**options)
      time_zone_rfc2822
    end

    def char(char, *alternatives, raise do_raise = true)
      if current_char == char || alternatives.includes?(current_char)
        next_char
        true
      else
        if do_raise
          raise "Unexpected char: #{current_char.inspect} (#{@reader.pos})"
        end
        false
      end
    end

    def char?(char, *alternatives)
      char(char, *alternatives, raise: false)
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

    def whitespace
      unless current_char.ascii_whitespace?
        raise "Unexpected char: #{current_char.inspect} (#{@reader.pos})"
      end
      next_char
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
