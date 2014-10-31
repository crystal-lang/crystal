struct TimeFormat
  MONTH_NAMES = %w(January February March April May June July August September October November December)
  DAY_NAMES = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

  getter pattern

  def initialize(@pattern : String)
  end

  def format(time : Time)
    String.build do |str|
      format time, str
    end
  end

  def format(time : Time, io : IO)
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
          percent_a time, io
        when 'A'
          io << day_name(time)
        when 'b', 'h'
          percent_b time, io
        when 'c'
          percent_a time, io
          char ' ', io
          percent_b time, io
          char ' ', io
          percent_e time, io
          char ' ', io
          percent_T time, io
          char ' ', io
          percent_Y time, io
        when 'B'
          io << month_name(time)
        when 'C'
          io << time.year / 100
        when 'd'
          pad2 time.day, '0', io
        when 'D', 'x'
          percent_m time, io
          char '/', io
          percent_d time, io
          char '/', io
          percent_y time, io
        when 'e'
          percent_e time, io
        when 'F'
          percent_Y time, io
          char '-', io
          percent_m time, io
          char '-', io
          percent_d time, io
        when 'j'
          pad3 time.day_of_year, '0', io
        when 'H'
          percent_H time, io
        when 'I'
          percent_I time, io
        when 'k'
          pad2 time.hour, ' ', io
        when 'l'
          pad2 (time.hour % 12), ' ', io
        when 'L'
          pad3 time.millisecond, '0', io
        when 'm'
          percent_m time, io
        when 'M'
          percent_M time, io
        when 'p'
          io << (time.hour < 12 ? "am" : "pm")
        when 'P'
          percent_P time, io
        when 'r'
          percent_I time, io
          char ':', io
          percent_M time, io
          char ':', io
          percent_S time, io
          char ' ', io
          percent_P time, io
        when 'R'
          percent_H time, io
          char ':', io
          percent_M time, io
        when 'S'
          percent_S time, io
        when 'T'
          percent_T time, io
        when 'u'
          v = time.day_of_week
          v = 7 if v == 0
          io << v
        when 'w'
          io << time.day_of_week
        when 'X'
          percent_T time, io
        when 'y'
          percent_y time, io
        when 'Y'
          percent_Y time, io
        when '_'
          i += 1
          byte = str[i]
          case byte.chr
          when 'm'
            pad2 time.month, ' ', io
          else
            char '%', io
            char '_', io
            io.write_byte byte
          end
        when '-'
          i += 1
          byte = str[i]
          case byte.chr
          when 'd'
            io << time.day
          when 'm'
            io << time.month
          else
            char '%', io
            char '-', io
            io.write_byte byte
          end
        when '^'
          i += 1
          byte = str[i]
          case byte.chr
          when 'A'
            io << day_name(time).upcase
          when 'b', 'h'
            io << short_month_name(time).upcase
          when 'B'
            io << month_name(time).upcase
          else
            char '%', io
            char '^', io
            io.write_byte byte
          end
        when '%'
          char '%', io
        else
          char '%', io
          io.write_byte byte
        end
      else
        io.write_byte byte
      end

      i += 1
    end
  end

  private def percent_a(time, io)
    io << short_day_name(time)
  end

  private def percent_b(time, io)
    io << short_month_name(time)
  end

  private def percent_d(time, io)
    pad2 time.day, '0', io
  end

  private def percent_e(time, io)
    pad2 time.day, ' ', io
  end

  private def percent_H(time, io)
    pad2 time.hour, '0', io
  end

  private def percent_I(time, io)
    pad2 (time.hour % 12), '0', io
  end

  private def percent_m(time, io)
    pad2 time.month, '0', io
  end

  private def percent_M(time, io)
    pad2 time.minute, '0', io
  end

  private def percent_P(time, io)
    io << (time.hour < 12 ? "AM" : "PM")
  end

  private def percent_S(time, io)
    pad2 time.second, '0', io
  end

  private def percent_T(time, io)
    percent_H time, io
    char ':', io
    percent_M time, io
    char ':', io
    percent_S time, io
  end

  private def percent_y(time, io)
    io << time.year % 100
  end

  private def percent_Y(time, io)
    io << time.year
  end

  private def char(char, io)
    io.write_byte char.ord.to_u8
  end

  private def month_name(time)
    MONTH_NAMES[time.month]
  end

  private def short_month_name(time)
    month_name(time)[0, 3]
  end

  private def day_name(time)
    DAY_NAMES[time.day_of_week]
  end

  private def short_day_name(time)
    day_name(time)[0, 3]
  end

  private def pad2(value, padding, io)
    io.write_byte padding.ord.to_u8 if value < 10
    io << value
  end

  private def pad3(value, padding, io)
    io.write_byte padding.ord.to_u8 if value < 100
    pad2 value, padding, io
  end
end
