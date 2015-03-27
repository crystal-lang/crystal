class String::Formatter
  def initialize(string, @args, @io)
    @reader = CharReader.new(string)
    @arg_index = 0
  end

  def format
    while has_next?
      case char = current_char
      when '%'
        case char = next_char
        when 's' then string
        when 'd', 'b', 'o', 'x'
          number base: base(char)
        when '0'
          consume_padding('0')
        when '1' .. '9'
          consume_padding(' ')
        when '+'
          case char = next_char
          when 'd', 'b', 'o', 'x'
            number base: base(char), plus: true
          when '0'
            consume_padding '0', plus: true
          when '1' .. '9'
            consume_padding ' ', plus: true
          else
            raise ArgumentError.new("malformed format string - %+#{char}")
          end
        when ' '
          case char = next_char
          when 'd', 'b', 'o', 'x'
            number base: base(char), space: true
          when '0'
            consume_padding '0', space: true
          when '1' .. '9'
            consume_padding ' ', space: true
          else
            raise "malformed format string - % #{char}"
          end
        when '-'
          case char = next_char
          when 's'
            string
          when 'd', 'b', 'o', 'x'
            number base: base(char)
          when '1' .. '9'
            consume_padding ' ', right: true
          when '+'
            case char = next_char
            when '1' .. '9'
              consume_padding ' ', plus: true, right: true
            else
              # TODO
            end
          when ' '
            case char = next_char
            when '1' .. '9'
              consume_padding ' ', space: true, right: true
            else
              # TODO
            end
          else
            # TODO
          end
        when '%'
          char '%'
        else
          # TODO
        end
      else
        char char
      end
      char = next_char
    end
  end

  private def consume_padding(fill_char, right = false, plus = false, space = false)
    num = consume_number
    case char = current_char
    when 's'
      string padding: fill_char, padding_count: num, right: right
    when 'd', 'b', 'o', 'x'
      number base: base(char), padding: fill_char, padding_count: num, right: right, plus: plus, space: space
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

  def string(padding = nil, padding_count = 0, right = false)
    arg = next_arg
    pad padding_count, arg.to_s.length, padding if padding && !right
    @io << arg
    pad padding_count, arg.to_s.length, padding if padding && right
  end

  def number(base = 10, padding = nil, padding_count = 0, right = false, plus = false, space = false)
    arg = next_arg
    unless arg.responds_to?(:to_i)
      raise ArgumentError.new("expected a number, not #{arg.inspect}")
    end

    int = arg.to_i

    if padding && !right
      if padding == '0'
        @io << '+' if plus
        @io << ' ' if space
      end

      pad_number int, base, plus, space, padding_count, padding
    end

    if int > 0
      unless padding == '0'
        @io << '+' if plus
        @io << ' ' if space
      end
    end

    int.to_s(base, @io)

    if padding && right
      pad_number int, base, plus, space, padding_count, padding
    end
  end

  def pad(total, consumed, padding)
    (total - consumed).times do
      @io << padding
    end
  end

  def pad_number(int, base, plus, space, padding_count, padding)
    size = int.to_s(base).bytesize
    size += 1 if int > 0 && (plus || space)
    pad padding_count, size, padding
  end

  def char(char)
    @io << char
  end

  private def current_arg
    @args.at(@arg_index) { raise ArgumentError.new("too few arguments") }
  end

  def next_arg
    current_arg.tap { @arg_index += 1 }
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

  private def base(char)
    case char
    when 'b' then 2
    when 'o' then 8
    when 'x' then 16
    else          10
    end
  end
end
