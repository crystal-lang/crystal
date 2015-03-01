# TODO: this is not UTF-8 aware
class String::Formatter
  def initialize(string, @args, @buffer)
    @i = 0
    @arg_index = 0
    @length = string.bytesize
    @str = string.cstr
  end

  def format
    while @i < @length
      case char = current_char
      when '%'
        @i += 1
        case char = current_char
        when 's'
          append_string do |arg, arg_s|
            @buffer << arg_s
          end
        when 'd'
          append_integer do |arg, arg_s|
            @buffer << arg_s
          end
        when 'b'
          append_integer(2) do |arg, arg_s|
            @buffer << arg_s
          end
        when 'o'
          append_integer(8) do |arg, arg_s|
            @buffer << arg_s
          end
        when 'x'
          append_integer(16) do |arg, arg_s|
            @buffer << arg_s
          end
        when '0'
          append_with_left_padding('0')
        when '1' .. '9'
          append_with_left_padding(' ')
        when '+'
          @i += 1
          case char = current_char
          when 'd'
            append_integer do |arg, arg_s|
              @buffer << '+' if arg >= 0
              @buffer << arg_s
            end
          when '0'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              @buffer << '+' if arg >= 0
              num.times { @buffer << '0' }
              @buffer << arg_s
            end
          when '1' .. '9'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              num.times { @buffer << ' ' }
              @buffer << '+' if arg >= 0
              @buffer << arg_s
            end
          else
            raise "malformed format string - %+#{char}"
          end
        when ' '
          @i += 1
          case char = current_char
          when 'd'
            append_integer do |arg, arg_s|
              @buffer << ' ' if arg >= 0
              @buffer << arg_s
            end
          when '0'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              num -= 1 if arg >= 0
              @buffer << ' ' if arg >= 0
              num.times { @buffer << '0' }
              @buffer << arg_s
            end
          when '1' .. '9'
            append_with_left_padding(' ')
          else
            raise "malformed format string - % #{char}"
          end
        when '-'
          @i += 1
          case char = current_char
          when 'd'
            append_integer do |arg, arg_s|
              @buffer << arg_s
            end
          when 's'
            append_string do |arg, arg_s|
              @buffer << arg_s
            end
          when '1' .. '9'
            append_with_padding do |arg, arg_s, num|
              num -= arg_s.bytesize
              @buffer << arg_s
              num.times { @buffer << ' ' }
            end
          when '+'
            @i += 1
            case char = current_char
            when '1' .. '9'
              append_with_padding do |arg, arg_s, num|
                num -= arg_s.bytesize
                if arg >= 0
                  num -= 1
                  @buffer << '+'
                end
                @buffer << arg_s
                num.times { @buffer << ' ' }
              end
            else
              # TODO
            end
          when ' '
            @i += 1
            case char = current_char
            when '1' .. '9'
              append_with_padding do |arg, arg_s, num|
                num -= arg_s.bytesize
                if arg >= 0
                  num -= 1
                  @buffer << ' '
                end
                @buffer << arg_s
                num.times { @buffer << ' ' }
              end
            else
              # TODO
            end
          else
            # TODO
          end
        when '%'
          @i += 1
          @buffer << '%'
        else
          # TODO
        end
      else
        @i += 1
        @buffer << char
      end
    end
  end

  private def append_string
    append_arg(@args[@arg_index]) { |arg, arg_s| yield arg, arg_s }
  end

  private def append_integer(base=10)
    arg = @args[@arg_index]
    unless arg.responds_to?(:to_i)
      raise "expected a number for %d, not #{arg.inspect}"
    end

    append_arg(arg.to_i, arg.to_i.to_s(base)) { |arg_i, arg_s| yield arg_i, arg_s }
  end

  private def append_arg(arg, arg_s=nil)
    arg_s ||= arg.to_s
    yield arg, arg_s
    @arg_index += 1
    @i += 1
  end

  private def append_with_left_padding(fill_char)
    append_with_padding do |arg, arg_s, num|
      num -= arg_s.bytesize
      num.times { @buffer << fill_char }
      @buffer << arg_s
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
      append_arg(@args[@arg_index]) do |arg, arg_s|
        yield -1, arg_s, num
      end
    else
      # TODO
    end
  end

  private def consume_number
    num = current_char.ord - '0'.ord
    @i += 1
    while @i < @length
      case char = current_char
      when '0' .. '9'
        @i += 1
        num *= 10
        num += char.ord - '0'.ord
      else
        break
      end
    end
    num
  end

  private def current_char
    @str[@i].chr
  end
end
