# Specifies the format to convert a `Time` to and from a `String`.
struct Time::Format::Pattern
  include Time::Format

  # Returns the string pattern of this format.
  getter pattern : String

  # Creates a new `Time::Format` with the given *pattern*. The given time
  # *kind* will be used when parsing a `Time` and no time zone is found in it.
  def initialize(@pattern : String, @kind = Time::Kind::Unspecified)
  end

  # Parses a string into a `Time`.
  def parse(string, kind = @kind) : Time
    parser = Parser.new(string)
    parser.visit(pattern)
    parser.time(kind)
  end

  # Formats a `Time` into the given *io*.
  def format(time : Time, io : IO)
    formatter = Formatter.new(time, io)
    formatter.visit(pattern)
    io
  end

  # :nodoc:
  module Visitor
    def visit(pattern)
      reader = Char::Reader.new(pattern)
      while reader.has_next?
        char = reader.current_char
        reader = check_char reader, char
        reader.next_char
      end
    end

    private def check_char(reader, char)
      case char
      when '%'
        case char = reader.next_char
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
          year_month_day
        when 'H'
          hour_24_zero_padded
        when 'I'
          hour_12_zero_padded
        when 'j'
          day_of_year_zero_padded
        when 'k'
          hour_24_blank_padded
        when 'l'
          hour_12_blank_padded
        when 'L'
          milliseconds
        when 'm'
          month_zero_padded
        when 'M'
          minute
        when 'N'
          nanoseconds
        when 'p'
          am_pm
        when 'P'
          am_pm_upcase
        when 'r'
          twelve_hour_time
        when 'R'
          twenty_four_hour_time
        when 's'
          epoch
        when 'S'
          second
        when 'T', 'X'
          twenty_four_hour_time_with_seconds
        when 'u'
          day_of_week_monday_1_7
        when 'w'
          day_of_week_sunday_0_6
        when 'y'
          year_modulo_100
        when 'Y'
          year
        when 'z'
          time_zone
        when '_'
          case char = reader.next_char
          when 'm'
            month_blank_padded
          else
            char '%'
            char '_'
            reader = check_char reader, char
          end
        when '-'
          case char = reader.next_char
          when 'd'
            day_of_month
          when 'm'
            month
          else
            char '%'
            char '-'
            reader = check_char reader, char
          end
        when '^'
          case char = reader.next_char
          when 'a'
            short_day_name_upcase
          when 'A'
            day_name_upcase
          when 'b', 'h'
            short_month_name_upcase
          when 'B'
            month_name_upcase
          else
            char '%'
            char '^'
            reader = check_char reader, char
          end
        when ':'
          case char = reader.next_char
          when 'z'
            time_zone_colon
          when ':'
            case char = reader.next_char
            when 'z'
              time_zone_colon_with_seconds
            else
              char '%'
              char ':'
              char ':'
              reader = check_char reader, char
            end
          else
            char '%'
            char ':'
            reader = check_char reader, char
          end
        when '%'
          char '%'
        else
          char '%'
          char char
        end
      else
        char char
      end
      reader
    end
  end

  # :nodoc:
  struct Parser
    include Visitor
    include Time::Format::Parser
  end

  # :nodoc:
  struct Formatter
    include Visitor
    include Time::Format::Formatter
  end
end
