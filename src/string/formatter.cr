class String::Formatter
  def initialize(string, @args, @io)
    @reader = CharReader.new(string)
    @arg_index = 0
  end

  def format
    while true
      case char = current_char
      when '\0'
        break
      when '%'
        consume_percent
      else
        char char
      end
      next_char
    end
  end

  private def consume_percent
    next_char
    flags = consume_flags
    flags = consume_width(flags)
    consume_type(flags)
  end

  private def consume_flags
    flags = Flags.new
    while true
      case current_char
      when ' '
        flags.space = true
      when '#'
        flags.sharp = true
      when '+'
        flags.plus = true
      when '-'
        flags.minus = true
      when '0'
        flags.zero = true
      else
        break
      end
      next_char
    end
    flags
  end

  private def consume_width(flags)
    if '1' <= current_char <= '9'
      flags.width = consume_number
    end
    flags
  end

  private def consume_number
    num = current_char.ord - '0'.ord
    next_char
    while true
      case char = current_char
      when '0' .. '9'
        num *= 10
        num += char.ord - '0'.ord
      else
        break
      end
      next_char
    end
    num
  end

  private def consume_type(flags)
    case char = current_char
    when 's'
      string flags
    when 'b'
      flags.base = 2
      number flags
    when 'o'
      flags.base = 8
      number flags
    when 'd'
      flags.base = 10
      number flags
    when 'x'
      flags.base = 16
      number flags
    when '%'
      char '%'
    else
      raise ArgumentError.new("malformed format string - %#{char}")
    end
  end

  def string(flags)
    arg = next_arg

    pad arg.to_s.length, flags if flags.left_padding?
    @io << arg
    pad arg.to_s.length, flags if flags.right_padding?
  end

  def number(flags)
    arg = next_arg
    unless arg.responds_to?(:to_i)
      raise ArgumentError.new("expected a number, not #{arg.inspect}")
    end

    int = arg.is_a?(Int) ? arg : arg.to_i

    if flags.left_padding?
      if flags.padding_char == '0'
        @io << '+' if flags.plus
        @io << ' ' if flags.space
      end

      pad_number int, flags
    end

    if int > 0
      unless flags.padding_char == '0'
        @io << '+' if flags.plus
        @io << ' ' if flags.space
      end
    end

    int.to_s(flags.base, @io)

    if flags.right_padding?
      pad_number int, flags
    end
  end

  def pad(consumed, flags)
    padding_char = flags.padding_char
    (flags.width - consumed).times do
      @io << padding_char
    end
  end

  def pad_number(int, flags)
    size = int.to_s(flags.base).bytesize
    size += 1 if int > 0 && (flags.plus || flags.space)
    pad size, flags
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

  private def current_char
    @reader.current_char
  end

  private def next_char
    @reader.next_char
  end

  struct Flags
    property space, sharp, plus, minus, zero, width, base

    def initialize
      @space = @sharp = @plus = @minus = @zero = false
      @width = 0
      @base = 10
    end

    def wants_padding?
      @width > 0
    end

    def left_padding?
      wants_padding? && !@minus
    end

    def right_padding?
      wants_padding? && @minus
    end

    def padding_char
      @zero ? '0' : ' '
    end
  end
end
