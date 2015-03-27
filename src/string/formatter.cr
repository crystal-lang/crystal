class String::Formatter
  def initialize(string, @args, @out)
    @reader = CharReader.new(string)
    @arg_index = 0
  end

  def format
    while has_next?
      case char = current_char
      when '%'
        case char = next_char
        when 's'
          append_string do |arg, arg_s|
            @out << arg_s
          end
        when 'd'
          append_integer do |arg, arg_s|
            @out << arg_s
          end
        when 'b'
          append_integer(char, 2) do |arg, arg_s|
            @out << arg_s
          end
        when 'o'
          append_integer(char, 8) do |arg, arg_s|
            @out << arg_s
          end
        when 'x'
          append_integer(char, 16) do |arg, arg_s|
            @out << arg_s
          end
        when '0'
          append_with_left_padding('0')
        when '1' .. '9'
          append_with_left_padding(' ')
        when '+'
          case char = next_char
          when 'd'
            append_integer do |arg, arg_s|
              @out << '+' if arg >= 0
              @out << arg_s
            end
          when 'b'
            append_integer(char, 2) do |arg, arg_s|
              @out << '+' if arg >= 0
              @out << arg_s
            end
          when 'o'
            append_integer(char, 8) do |arg, arg_s|
              @out << '+' if arg >= 0
              @out << arg_s
            end
          when 'x'
            append_integer(char, 16) do |arg, arg_s|
              @out << '+' if arg >= 0
              @out << arg_s
            end
          when '0'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              @out << '+' if arg >= 0
              num.times { @out << '0' }
              @out << arg_s
            end
          when '1' .. '9'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              num.times { @out << ' ' }
              @out << '+' if arg >= 0
              @out << arg_s
            end
          else
            raise "malformed format string - %+#{char}"
          end
        when ' '
          case char = next_char
          when 'd'
            append_integer do |arg, arg_s|
              @out << ' ' if arg >= 0
              @out << arg_s
            end
          when 'b'
            append_integer(char, 2) do |arg, arg_s|
              @out << ' ' if arg >= 0
              @out << arg_s
            end
          when 'o'
            append_integer(char, 8) do |arg, arg_s|
              @out << ' ' if arg >= 0
              @out << arg_s
            end
          when 'x'
            append_integer(char, 16) do |arg, arg_s|
              @out << ' ' if arg >= 0
              @out << arg_s
            end
          when '0'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              @out << ' ' if arg >= 0
              num.times { @out << '0' }
              @out << arg_s
            end
          when '1' .. '9'
            append_with_left_padding(' ')
          else
            raise "malformed format string - % #{char}"
          end
        when '-'
          case char = next_char
          when 'd'
            append_integer do |arg, arg_s|
              @out << arg_s
            end
          when 'b'
            append_integer(char, 2) do |arg, arg_s|
              @out << arg_s
            end
          when 'o'
            append_integer(char, 8) do |arg, arg_s|
              @out << arg_s
            end
          when 'x'
            append_integer(char, 16) do |arg, arg_s|
              @out << arg_s
            end
          when 's'
            append_string do |arg, arg_s|
              @out << arg_s
            end
          when '1' .. '9'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              @out << arg_s
              num.times { @out << ' ' }
            end
          when '+'
            case char = next_char
            when '1' .. '9'
              append_with_padding do |arg, arg_s, num|
                num -= arg_s.bytesize
                if arg >= 0
                  num -= 1
                  @out << '+'
                end
                @out << arg_s
                num.times { @out << ' ' }
              end
            else
              # TODO
            end
          when ' '
            case char = next_char
            when '1' .. '9'
              append_with_padding do |arg, arg_s, num|
                num -= arg_s.bytesize
                if arg >= 0
                  num -= 1
                  @out << ' '
                end
                @out << arg_s
                num.times { @out << ' ' }
              end
            else
              # TODO
            end
          else
            # TODO
          end
        when '%'
          @out << '%'
          next_char
        else
          # TODO
        end
      else
        @out << char
        next_char
      end
    end
  end

  private def append_string
    append_arg(current_arg) { |arg, arg_s| yield arg, arg_s }
  end

  private def append_integer(char = 'd', base = 10)
    arg = current_arg
    unless arg.responds_to?(:to_i)
      raise "expected a number for %#{char}, not #{arg.inspect}"
    end

    arg_to_i = arg.is_a?(Int) ? arg : arg.to_i
    append_arg(arg_to_i, arg_to_i.to_s(base)) { |arg_i, arg_s| yield arg_i, arg_s }
  end

  private def append_arg(arg, arg_s = arg.to_s)
    yield arg, arg_s
    @arg_index += 1
    next_char
  end

  private def append_with_left_padding(fill_char)
    append_with_padding do |arg, arg_s, num|
      num -= arg_s.bytesize
      num.times { @out << fill_char }
      @out << arg_s
    end
  end

  private def append_with_padding
    num = consume_number
    case char = current_char
    when 'd'
      append_integer do |arg, arg_s|
        yield arg, arg_s, num
      end
    when 's'
      append_arg(current_arg) do |arg, arg_s|
        yield -1, arg_s, num
      end
    else
      # TODO
    end
  end

  private def consume_number
    num = current_char.ord - '0'.ord
    next_char
    while has_next?
      case char = current_char
      when '0' .. '9'
        num *= 10
        num += char.ord - '0'.ord
        next_char
      else
        break
      end
    end
    num
  end

  private def current_arg
    @args.at(@arg_index) { raise ArgumentError.new("too few arguments") }
  end

  private def has_next?
    @reader.has_next?
  end

  private def current_char
    @reader.current_char
  end

  private def next_char
    @reader.next_char
  end
end
