require "c/stdio"

# :nodoc:
struct String::Formatter(A)
  # FIXME: wasm32 appears to run out of memory if we use Ryu Printf, which
  # initializes very large lookup tables, so we fall back to `LibC.snprintf` for
  # the floating-point format specifiers (#13918)
  {% begin %}
    HAS_RYU_PRINTF = {{ !flag?(:wasm32) }}
  {% end %}

  private enum Mode
    None

    # `%s`, index type is `Nil`
    Sequential

    # `%1$s`, index type is `Int32`
    Numbered

    # `%{a}` or `%<b>s`, index type is `String`
    Named
  end

  {% unless HAS_RYU_PRINTF %}
    @format_buf = Pointer(UInt8).null
    @format_buf_len = 0

    @temp_buf = Pointer(UInt8).null
    @temp_buf_len = 0
  {% end %}

  @arg_mode : Mode = :none

  def initialize(string, @args : A, @io : IO)
    @reader = Char::Reader.new(string)
    @arg_index = 0
  end

  def format : Nil
    while @reader.has_next?
      case char = current_char
      when '%'
        consume_percent
      else
        @io << char
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
    when '%'
      @io << '%'
    else
      flags = consume_flags
      consume_type flags, nil
    end
  end

  private def consume_substitution : Nil
    key = consume_substitution_key '}'
    # note: "`@io << (arg_at(key))` has no type" without this `arg` variable
    arg = arg_at(key)
    @io << arg
  end

  private def consume_formatted_substitution
    key = consume_substitution_key '>'
    args_are :named
    next_char
    flags = consume_flags
    consume_type flags, key
  end

  private def consume_substitution_key(end_char)
    String.build do |io|
      loop do
        unless @reader.has_next?
          raise ArgumentError.new "Malformed name - unmatched parenthesis"
        end

        case current_char
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
    flags = consume_format_flags_and_width
    flags = consume_precision(flags)
    flags
  end

  private def consume_format_flags_and_width
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
      when '1'..'9'
        val, size = consume_number
        if current_char == '$'
          args_are :numbered
          raise ArgumentError.new("Cannot specify parameter number more than once") if flags.index
          flags.index = val
          next_char
          next
        else
          flags.width = val
          {% unless HAS_RYU_PRINTF %}
            flags.width_size = size
          {% end %}
          break
        end
      when '*'
        val = consume_dynamic_value
        flags.width = val
        {% unless HAS_RYU_PRINTF %}
          flags.width_size = val.to_s.size
        {% end %}
        break
      else
        break
      end
      next_char
    end

    flags
  end

  private def consume_precision(flags)
    if current_char == '.'
      case next_char
      when '0'..'9'
        num, size = consume_number
        flags.precision = num
        {% unless HAS_RYU_PRINTF %}
          flags.precision_size = size
        {% end %}
      when '*'
        val = consume_dynamic_value
        if val >= 0
          flags.precision = val
          {% unless HAS_RYU_PRINTF %}
            flags.precision_size = val.to_s.size
          {% end %}
        end
      else
        flags.precision = 0
        {% unless HAS_RYU_PRINTF %}
          flags.precision_size = 1
        {% end %}
      end
    end
    flags
  end

  private def consume_dynamic_value
    next_char
    if current_char.in?('0'..'9')
      index, _ = consume_number
      unless current_char == '$'
        raise ArgumentError.new("Expected '$' after dynamic value '*' with parameter number")
      end
      next_char
    end

    value = arg_at(index)
    if value.is_a?(Int)
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

  private def consume_type(flags, index)
    # if coming from `%<foo>...`, then we already have `@arg_mode.named?`, so
    # supplying numbered parameters will raise
    arg = arg_at(flags.index || index)

    case char = current_char
    when 'c'
      char flags, arg
    when 's'
      string flags, arg
    when 'b'
      flags.base = 2
      flags.type = char
      int flags, arg
    when 'o'
      flags.base = 8
      flags.type = char
      int flags, arg
    when 'd', 'i'
      flags.base = 10
      int flags, arg
    when 'x', 'X'
      flags.base = 16
      flags.type = char
      int flags, arg
    when 'a', 'A', 'e', 'E', 'f', 'g', 'G'
      flags.type = char
      flags.float = true
      float flags, arg
    else
      raise ArgumentError.new("Malformed format string - %#{char.inspect}")
    end
  end

  def char(flags, arg) : Nil
    if arg.is_a?(Int::Primitive)
      arg = arg.chr
    end
    unless arg.is_a?(Char)
      raise ArgumentError.new("Expected a char or integer, not #{arg.inspect}")
    end
    pad 1, flags if flags.left_padding?
    @io << arg
    pad 1, flags if flags.right_padding?
  end

  def string(flags, arg) : Nil
    if precision = flags.precision
      arg = arg.to_s[0...precision]
    end

    pad arg.to_s.size, flags if flags.left_padding?
    @io << arg
    pad arg.to_s.size, flags if flags.right_padding?
  end

  def int(flags, arg : Int) : Nil
    precision = int_precision(arg, flags)
    base_str = arg.to_s(flags.base, precision: precision, upcase: flags.uppercase?)
    str_size = base_str.bytesize
    str_size += 1 if arg >= 0 && (flags.plus || flags.space)
    str_size += 2 if flags.sharp && flags.base != 10 && arg != 0

    # If `arg` is zero-padded, we let the precision argument do the right-justification
    pad(str_size, flags) if flags.left_padding? && flags.padding_char != '0'

    write_plus_or_space(arg, flags)

    if flags.sharp && arg < 0
      @io << '-'
      write_base_prefix(flags)
      @io.write_string base_str.unsafe_byte_slice(1)
    else
      write_base_prefix(flags) if flags.sharp && arg != 0
      @io << base_str
    end

    pad(str_size, flags) if flags.right_padding?
  end

  def int(flags, arg) : Nil
    raise ArgumentError.new("Expected an integer, not #{arg.inspect}") unless arg.responds_to?(:to_i)
    int(flags, arg.to_i)
  end

  private def write_plus_or_space(arg, flags)
    if arg >= 0
      if flags.plus
        @io << '+'
      elsif flags.space
        @io << ' '
      end
    end
  end

  private def write_base_prefix(flags)
    case flags.base
    when 2, 8, 16
      @io << '0' << flags.type
    end
  end

  private def int_precision(int, flags)
    if precision = flags.precision
      precision
    elsif flags.left_padding? && flags.padding_char == '0'
      width = flags.width
      width -= 1 if int < 0 || flags.plus || flags.space
      {width, 1}.max
    else
      1
    end
  end

  def float(flags, arg) : Nil
    if arg.responds_to?(:to_f64)
      float = arg.is_a?(Float64) ? arg : arg.to_f64

      if sign = float.infinite?
        float_special("inf", sign, flags)
      elsif float.nan?
        float_special("nan", 1, flags)
      else
        {% if HAS_RYU_PRINTF %}
          case flags.type
          when 'f'
            float_fixed(float, flags)
          when 'e', 'E'
            float_scientific(float, flags)
          when 'g', 'G'
            float_general(float, flags)
          when 'a', 'A'
            float_hex(float, flags)
          else
            raise "BUG: Unknown format type '#{flags.type}'"
          end
        {% else %}
          float_fallback(float, flags)
        {% end %}
      end
    else
      raise ArgumentError.new("Expected a float, not #{arg.inspect}")
    end
  end

  # Formats infinities and not-a-numbers
  private def float_special(str, sign, flags)
    str = str.upcase if flags.uppercase?
    str_size = str.bytesize
    str_size += 1 if sign < 0 || (flags.plus || flags.space)

    flags.zero = false
    pad(str_size, flags) if flags.left_padding?
    write_plus_or_space(sign, flags)
    @io << '-' if sign < 0
    @io << str
    pad(str_size, flags) if flags.right_padding?
  end

  {% if HAS_RYU_PRINTF %}
    # Formats floats with `%f`
    private def float_fixed(float, flags)
      # the longest string possible is due to `Float64::MIN_SUBNORMAL`, which
      # produces `0.` followed by 1074 nonzero digits; there is also no need
      # for any precision > 1074 because all trailing digits will be zeros
      if precision = flags.precision
        printf_precision = {precision.to_u32, 1074_u32}.min
        trailing_zeros = {precision - printf_precision, 0}.max
      else
        # default precision for C's `%f`
        printf_precision = 6_u32
        trailing_zeros = 0
      end

      printf_buf = uninitialized UInt8[1076]
      printf_size = Float::Printer::RyuPrintf.d2fixed_buffered_n(float, printf_precision, printf_buf.to_unsafe)
      printf_slice = printf_buf.to_slice[0, printf_size]
      dot_index = printf_slice.index('.'.ord)
      sign = float.sign_bit

      str_size = printf_size + trailing_zeros
      str_size += 1 if sign < 0 || flags.plus || flags.space
      str_size += 1 if flags.sharp && dot_index.nil?

      pad(str_size, flags) if flags.left_padding? && flags.padding_char != '0'

      # this preserves -0.0's sign correctly
      write_plus_or_space(sign, flags)
      @io << '-' if sign < 0

      pad(str_size, flags) if flags.left_padding? && flags.padding_char == '0'
      @io.write_string(printf_slice)
      trailing_zeros.times { @io << '0' }
      @io << '.' if flags.sharp && dot_index.nil?

      pad(str_size, flags) if flags.right_padding?
    end

    # Formats floats with `%e` or `%E`
    private def float_scientific(float, flags)
      # the longest string possible is due to
      # `Float64::MIN_POSITIVE.prev_float`, which produces `2.` followed by 766
      # nonzero digits and then `e-308`; there is also no need for any precision
      # > 766 because all trailing digits will be zeros
      if precision = flags.precision
        printf_precision = {precision.to_u32, 766_u32}.min
        trailing_zeros = {precision - printf_precision, 0}.max
      else
        # default precision for C's `%e`
        printf_precision = 6_u32
        trailing_zeros = 0
      end

      printf_buf = uninitialized UInt8[773]
      printf_size = Float::Printer::RyuPrintf.d2exp_buffered_n(float, printf_precision, printf_buf.to_unsafe)
      printf_slice = printf_buf.to_slice[0, printf_size]
      dot_index = printf_slice.index('.'.ord)
      e_index = printf_slice.rindex!('e'.ord)
      sign = float.sign_bit

      printf_slice[e_index] = 'E'.ord.to_u8! if flags.uppercase?

      str_size = printf_size + trailing_zeros
      str_size += 1 if sign < 0 || flags.plus || flags.space
      str_size += 1 if flags.sharp && dot_index.nil?
      str_size += 1 if printf_slice.size - e_index < 4

      pad(str_size, flags) if flags.left_padding? && flags.padding_char != '0'

      # this preserves -0.0's sign correctly
      write_plus_or_space(sign, flags)
      @io << '-' if sign < 0

      pad(str_size, flags) if flags.left_padding? && flags.padding_char == '0'
      @io.write_string(printf_slice[0, e_index])
      trailing_zeros.times { @io << '0' }
      @io << '.' if flags.sharp && dot_index.nil?
      @io.write_string(printf_slice[e_index, 2])
      @io << '0' if printf_slice.size - e_index < 4
      @io.write_string(printf_slice[(e_index + 2)..])

      pad(str_size, flags) if flags.right_padding?
    end

    # Formats floats with `%g` or `%G`
    private def float_general(float, flags)
      # `d2gen_buffered_n` will always take care of trailing zeros and return
      # the number of stripped digits
      precision = flags.precision.try(&.to_u32) || 6_u32

      printf_buf = uninitialized UInt8[773]
      printf_size, trailing_zeros =
        Float::Printer::RyuPrintf.d2gen_buffered_n(float.abs, precision, printf_buf.to_unsafe, flags.sharp)
      printf_slice = printf_buf.to_slice[0, printf_size]
      dot_index = printf_slice.index('.'.ord)
      e_index = printf_slice.rindex('e'.ord)
      sign = float.sign_bit

      printf_slice[e_index] = 'E'.ord.to_u8! if e_index && flags.uppercase?

      str_size = printf_size
      str_size += 1 if sign < 0 || flags.plus || flags.space
      str_size += (dot_index.nil? ? 1 : 0) + trailing_zeros if flags.sharp
      str_size += 1 if printf_slice.size - e_index < 4 if e_index

      pad(str_size, flags) if flags.left_padding? && flags.padding_char != '0'

      # this preserves -0.0's sign correctly
      write_plus_or_space(sign, flags)
      @io << '-' if sign < 0

      pad(str_size, flags) if flags.left_padding? && flags.padding_char == '0'
      @io.write_string(printf_slice[0...e_index])
      trailing_zeros.times { @io << '0' } if flags.sharp
      @io << '.' if flags.sharp && dot_index.nil?
      if e_index
        @io.write_string(printf_slice[e_index, 2])
        @io << '0' if printf_slice.size - e_index < 4
        @io.write_string(printf_slice[(e_index + 2)..])
      end

      pad(str_size, flags) if flags.right_padding?
    end

    # Formats floats with `%a` or `%A`
    private def float_hex(float, flags)
      sign = float.sign_bit
      float = float.abs

      str_size = Float::Printer::Hexfloat(Float64, UInt64).to_s_size(float,
        precision: flags.precision, alternative: flags.sharp)
      str_size += 1 if sign < 0 || flags.plus || flags.space

      pad(str_size, flags) if flags.left_padding? && flags.padding_char != '0'

      # this preserves -0.0's sign correctly
      write_plus_or_space(sign, flags)
      @io << '-' if sign < 0

      @io << (flags.uppercase? ? "0X" : "0x")
      pad(str_size, flags) if flags.left_padding? && flags.padding_char == '0'
      Float::Printer.hexfloat(float, @io,
        prefix: false, upcase: flags.uppercase?, precision: flags.precision, alternative: flags.sharp)

      pad(str_size, flags) if flags.right_padding?
    end
  {% else %}
    # Delegate to `LibC.snprintf` for float formats if Ryu Printf is unavailable
    private def float_fallback(float, flags)
      format_buf = recreate_float_format_string(flags)

      len = LibC.snprintf(nil, 0, format_buf, float) + 1
      temp_buf = temp_buf(len)
      LibC.snprintf(temp_buf, len, format_buf, float)

      @io.write_string Slice.new(temp_buf, len - 1)
    end

    # Here we rebuild the original format string, like %f or %.2g and use snprintf
    private def recreate_float_format_string(flags)
      capacity = 3 # percent + type + \0
      capacity += flags.width_size
      capacity += flags.precision_size + 1 # size + .
      capacity += 1 if flags.sharp
      capacity += 1 if flags.plus
      capacity += 1 if flags.minus
      capacity += 1 if flags.zero
      capacity += 1 if flags.space

      format_buf = format_buf(capacity)
      original_format_buf = format_buf

      io = IO::Memory.new(Bytes.new(format_buf, capacity))
      io << '%'
      io << '#' if flags.sharp
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
  {% end %} # HAS_RYU_PRINTF

  def pad(consumed, flags) : Nil
    padding_char = flags.padding_char
    (flags.width.abs - consumed).times do
      @io << padding_char
    end
  end

  def pad_int(int, flags) : Nil
    size = int.to_s(flags.base).bytesize
    size += 1 if int >= 0 && (flags.plus || flags.space)
    pad size, flags
  end

  private def arg_at(index : Nil)
    args_are :sequential
    arg = @args.fetch(@arg_index) { raise ArgumentError.new("Too few arguments") }
    @arg_index += 1
    arg
  end

  private def arg_at(index : Int)
    args_are :numbered
    raise ArgumentError.new "Parameter number cannot be 0" if index == 0
    @args.fetch(index - 1) { raise ArgumentError.new("Too few arguments") }
  end

  private def arg_at(index : String)
    args_are :named
    args = @args
    # note: "index '0' out of bounds for empty tuple" without the `is_a?` check
    # TODO: use `Tuple()` once support for 1.0.0 is dropped
    if args.size == 1 && !args.is_a?(Tuple(*typeof(Tuple.new)))
      arg = args[0]
      if arg.is_a?(Hash) || arg.is_a?(NamedTuple)
        return arg[index]
      end
    end
    raise ArgumentError.new "One hash or named tuple required"
  end

  private def args_are(mode : Mode)
    if @arg_mode.none?
      @arg_mode = mode
    elsif mode != @arg_mode
      raise ArgumentError.new "Cannot mix #{@arg_mode.to_s.downcase} parameters with #{mode.to_s.downcase} ones"
    end
  end

  private def current_char
    @reader.current_char
  end

  private def next_char
    @reader.next_char
  end

  struct Flags
    property space : Bool, sharp : Bool, plus : Bool, minus : Bool, zero : Bool, float : Bool, base : Int32
    property width : Int32
    property type : Char, precision : Int32?
    property index : Int32?

    {% unless HAS_RYU_PRINTF %}
      property width_size : Int32 = 0
      property precision_size : Int32 = 0
    {% end %}

    def initialize
      @space = @sharp = @plus = @minus = @zero = @float = false
      @width = 0
      @base = 10
      @type = ' '
      @precision = nil
    end

    def left_padding? : Bool
      !@minus && @width > 0
    end

    def right_padding? : Bool
      @minus || @width < 0
    end

    def padding_char : Char
      @zero && !right_padding? && (@float || !@precision) ? '0' : ' '
    end

    def uppercase? : Bool
      @type.ascii_uppercase?
    end
  end
end
