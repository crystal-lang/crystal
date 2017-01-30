require "c/stdio"

# :nodoc:
struct String::Formatter(A)
  @format_buf : Pointer(UInt8)?
  @temp_buf : Pointer(UInt8)?

  def initialize(string, @args : A, @io : IO)
    @reader = Char::Reader.new(string)
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
    case next_char
    when '{'
      next_char
      consume_substitution
    when '<'
      next_char
      consume_formatted_substitution
    else
      flags = consume_flags
      consume_type flags
    end
  end

  private def consume_substitution
    key = consume_substitution_key '}'
    arg = current_arg
    if arg.is_a?(Hash) || arg.is_a?(NamedTuple)
      @io << arg[key]
    else
      raise ArgumentError.new "One hash or named tuple required"
    end
  end

  private def consume_formatted_substitution
    key = consume_substitution_key '>'
    next_char
    arg = current_arg
    if arg.is_a?(Hash) || arg.is_a?(NamedTuple)
      target_arg = arg[key]
    else
      raise ArgumentError.new "One hash or named tuple required"
    end
    flags = consume_flags
    consume_type flags, target_arg, true
  end

  private def consume_substitution_key(end_char)
    String.build do |io|
      loop do
        case current_char
        when '\0'
          raise ArgumentError.new "Malformed name - unmatched parenthesis"
        when end_char
          break
        else
          io << current_char
        end
        next_char
      end
    end
  end

  private def consume_flags
    flags = consume_format_flags
    flags = consume_width(flags)
    flags = consume_precision(flags)
    flags
  end

  private def consume_format_flags
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
    case current_char
    when '1'..'9'
      num, size = consume_number
      flags.width = num
      flags.width_size = size
    when '*'
      val = consume_dynamic_value
      flags.width = val
      flags.width_size = val.to_s.size
    end
    flags
  end

  private def consume_precision(flags)
    if current_char == '.'
      case next_char
      when '1'..'9'
        num, size = consume_number
        flags.precision = num
        flags.precision_size = size
      when '*'
        val = consume_dynamic_value
        flags.precision = val
        flags.precision_size = val.to_s.size
      else
        flags.precision = 0
        flags.precision_size = 1
      end
    end
    flags
  end

  private def consume_dynamic_value
    value = current_arg
    if value.is_a?(Int)
      next_char
      next_arg
      value.to_i
    else
      raise ArgumentError.new("Expected dynamic value '*' to be an Int - #{value.inspect} (#{value.class.inspect})")
    end
  end

  private def consume_number
    num = current_char - '0'
    size = 1
    next_char
    while true
      case char = current_char
      when '0'..'9'
        num *= 10
        num += char - '0'
        size += 1
      else
        break
      end
      next_char
    end
    {num, size}
  end

  private def consume_type(flags, arg = nil, arg_specified = false)
    case char = current_char
    when 's'
      string flags, arg, arg_specified
    when 'b'
      flags.base = 2
      int flags, arg, arg_specified
    when 'o'
      flags.base = 8
      int flags, arg, arg_specified
    when 'd', 'i'
      flags.base = 10
      int flags, arg, arg_specified
    when 'x', 'X'
      flags.base = 16
      flags.type = char
      int flags, arg, arg_specified
    when 'a', 'A', 'e', 'E', 'f', 'g', 'G'
      flags.type = char
      float flags, arg, arg_specified
    when '%'
      char '%'
    else
      raise ArgumentError.new("Malformed format string - %#{char.inspect}")
    end
  end

  def string(flags, arg, arg_specified)
    arg = next_arg unless arg_specified

    if precision = flags.precision
      arg = arg.to_s[0...precision]
    end

    pad arg.to_s.size, flags if flags.left_padding?
    @io << arg
    pad arg.to_s.size, flags if flags.right_padding?
  end

  def int(flags, arg, arg_specified)
    arg = next_arg unless arg_specified

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
      raise ArgumentError.new("Expected an integer, not #{arg.inspect}")
    end
  end

  # We don't actually format the float ourselves, we delegate to sprintf
  def float(flags, arg, arg_specified)
    arg = next_arg unless arg_specified

    if arg.responds_to?(:to_f64)
      float = arg.is_a?(Float64) ? arg : arg.to_f64

      format_buf = recreate_float_format_string(flags)

      len = flags.width + (flags.precision || 0) + 23
      temp_buf = temp_buf(len)
      count = LibC.snprintf(temp_buf, len, format_buf, float)

      @io.write_utf8 Slice.new(temp_buf, count)
    else
      raise ArgumentError.new("Expected a float, not #{arg.inspect}")
    end
  end

  # Here we rebuild the original format string, like %f or %.2g and use snprintf
  def recreate_float_format_string(flags)
    capacity = 3 # percent + type + \0
    capacity += flags.width_size
    capacity += flags.precision_size + 1 # size + .
    capacity += 1 if flags.plus
    capacity += 1 if flags.minus
    capacity += 1 if flags.zero
    capacity += 1 if flags.space

    format_buf = format_buf(capacity)
    original_format_buf = format_buf

    io = IO::Memory.new(Bytes.new(format_buf, capacity))
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
    io.write_byte 0_u8

    original_format_buf
  end

  def pad(consumed, flags)
    padding_char = flags.padding_char
    (flags.width.abs - consumed).times do
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
    @args.at(@arg_index) { raise ArgumentError.new("Too few arguments") }
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
    property space : Bool, sharp : Bool, plus : Bool, minus : Bool, zero : Bool, base : Int32
    property width : Int32, width_size : Int32
    property type : Char, precision : Int32?, precision_size : Int32

    def initialize
      @space = @sharp = @plus = @minus = @zero = false
      @width = 0
      @width_size = 0
      @base = 10
      @type = ' '
      @precision = nil
      @precision_size = 0
    end

    def left_padding?
      @minus ? @width < 0 : @width > 0
    end

    def right_padding?
      @minus ? @width > 0 : @width < 0
    end

    def padding_char
      @zero ? '0' : ' '
    end
  end
end
