struct String::Formatter
  def initialize(string, @args, @io)
    @reader = CharReader.new(string)
    @arg_index = 0
    @temp_buf_len = 0
    @format_buf_len = 0
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
    flags = consume_precision(flags)
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
      num, length = consume_number
      flags.width = num
      flags.width_length = length
    end
    flags
  end

  private def consume_precision(flags)
    if current_char == '.'
      next_char
      if '1' <= current_char <= '9'
        num, length = consume_number
        flags.precision = num
        flags.precision_length = length + 1
      else
        flags.precision = 0
        flags.precision_length = 1
      end
    end
    flags
  end

  private def consume_number
    num = current_char.ord - '0'.ord
    length = 1
    next_char
    while true
      case char = current_char
      when '0' .. '9'
        num *= 10
        num += char.ord - '0'.ord
        length += 1
      else
        break
      end
      next_char
    end
    {num, length}
  end

  private def consume_type(flags)
    case char = current_char
    when 's'
      string flags
    when 'b'
      flags.base = 2
      int flags
    when 'o'
      flags.base = 8
      int flags
    when 'd', 'i'
      flags.base = 10
      int flags
    when 'x', 'X'
      flags.base = 16
      flags.type = char
      int flags
    when 'a', 'A', 'e', 'E', 'f', 'g', 'G'
      flags.type = char
      float flags
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

  def int(flags)
    arg = next_arg
    if arg.responds_to?(:to_i)
      int = arg.is_a?(Int) ? arg : arg.to_i

      if flags.left_padding?
        if flags.padding_char == '0'
          @io << '+' if flags.plus
          @io << ' ' if flags.space
        end

        pad_int int, flags
      end

      if int > 0
        unless flags.padding_char == '0'
          @io << '+' if flags.plus
          @io << ' ' if flags.space
        end
      end

      int.to_s(flags.base, @io, upcase: flags.type == 'X')

      if flags.right_padding?
        pad_int int, flags
      end
    else
      raise ArgumentError.new("expected an integer, not #{arg.inspect}")
    end
  end

  # We don't actually format the float ourselves, we delegate to sprintf
  def float(flags)
    arg = next_arg
    if arg.responds_to?(:to_f)
      float = arg.is_a?(Float) ? arg : arg.to_f

      format_buf = recreate_float_format_string(flags)

      len = flags.width + (flags.precision || 0) + 23
      temp_buf = temp_buf(len)
      count = LibC.snprintf(temp_buf, len, format_buf, float)

      @io.write Slice.new(temp_buf, count)
    else
      raise ArgumentError.new("expected a float, not #{arg.inspect}")
    end
  end

  # Here we rebuild the original format string, like %f or %.2g and use snprintf
  def recreate_float_format_string(flags)
    capacity = 2 # percent + type
    capacity += flags.width_length
    capacity += flags.precision_length
    capacity += 1 if flags.plus
    capacity += 1 if flags.minus
    capacity += 1 if flags.zero
    capacity += 1 if flags.space

    format_buf = format_buf(capacity)
    original_format_buf = format_buf

    io = PointerIO.new(pointerof(format_buf))
    io << '%'
    io << '+' if flags.plus
    io << '-' if flags.minus
    io << '0' if flags.zero
    io << ' ' if flags.space
    io << flags.width if flags.width > 0
    if precision = flags.precision
      io << '.'
      io << precision if precision != 0
    end
    io << flags.type

    original_format_buf
  end

  def pad(consumed, flags)
    padding_char = flags.padding_char
    (flags.width - consumed).times do
      @io << padding_char
    end
  end

  def pad_int(int, flags)
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

  # We reuse a temporary buffer for snprintf
  private def temp_buf(len)
    temp_buf = @temp_buf
    if temp_buf
      if len > @temp_buf_len
        @temp_buf_len = len
        @temp_buf = temp_buf = temp_buf.realloc(len)
      end
      temp_buf
    else
      @temp_buf = Pointer(UInt8).malloc(len)
    end
  end

  # We reuse a temporary buffer for the float format string
  private def format_buf(len)
    format_buf = @format_buf
    if format_buf
      if len > @format_buf_len
        @format_buf_len = len
        @format_buf = format_buf = format_buf.realloc(len)
      end
      format_buf
    else
      @format_buf = Pointer(UInt8).malloc(len)
    end
  end

  struct Flags
    property space, sharp, plus, minus, zero, base
    property width, width_length
    property type, precision, precision_length

    def initialize
      @space = @sharp = @plus = @minus = @zero = false
      @width = 0
      @width_length = 0
      @base = 10
      @type = ' '
      @precision = nil
      @precision_length = 0
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
