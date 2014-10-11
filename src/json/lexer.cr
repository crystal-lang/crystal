require "string_pool"

class Json::Lexer
  getter token
  property skip

  def initialize(string)
    @reader = CharReader.new(string)
    @token = Token.new
    @line_number = 1
    @column_number = 1
    @buffer = StringIO.new
    @string_pool = StringPool.new
    @skip = false
  end

  def next_token
    skip_whitespace

    @token.line_number = @line_number
    @token.column_number = @column_number

    case current_char
    when '\0'
      @token.type = :EOF
    when '{'
      next_char :"{"
    when '}'
      next_char :"}"
    when '['
      next_char :"["
    when ']'
      next_char :"]"
    when ','
      next_char :","
    when ':'
      next_char :":"
    when 'f'
      consume_false
    when 'n'
      consume_null
    when 't'
      consume_true
    when '"'
      consume_string
    else
      consume_number
    end

    @token
  end

  # Requests the next token where the parser expects a json
  # object key. In this case the lexer tries to reuse the String
  # instances by using a StringPool.
  def next_token_expect_object_key
    @expects_object_key = true
    next_token
    @expects_object_key = false
    @token
  end

  private def skip_whitespace
    while current_char.whitespace?
      if current_char == '\n'
        @line_number += 1
        @column_number = 0
      end
      next_char
    end
  end

  private def consume_true
    if next_char == 'r' && next_char == 'u' && next_char == 'e'
      next_char
      @token.type = :true
    else
      unexpected_char
    end
  end

  private def consume_false
    if next_char == 'a' && next_char == 'l' && next_char == 's' && next_char == 'e'
      next_char
      @token.type = :false
    else
      unexpected_char
    end
  end

  private def consume_null
    if next_char == 'u' && next_char == 'l' && next_char == 'l'
      next_char
      @token.type = :null
    else
      unexpected_char
    end
  end

  private def consume_string
    start_pos = current_pos

    # A simple string is one that doesn't have an escape character.
    # In that case we can build a string by doing a subslice of the original string.
    simple_string = true

    while true
      case char = next_char
      when '\0'
        raise "unterminated string"
      when '\\'
        # If we find an escape character, accumulate everything so
        # far in the buffer and continue appending to it from now on.
        if simple_string && !@skip
          clear_buffer
          write_to_buffer slice_range(start_pos + 1, current_pos)
          simple_string = false
        end

        case char = next_char
        when '\\', '"', '/'
          append_to_buffer char unless simple_string
        when 'b'
          append_to_buffer '\b' unless simple_string
        when 'f'
          append_to_buffer '\f' unless simple_string
        when 'n'
          append_to_buffer '\n' unless simple_string
        when 'r'
          append_to_buffer '\r' unless simple_string
        when 't'
          append_to_buffer '\t' unless simple_string
        when 'u'
          hexnum1 = read_hex_number
          if hexnum1 > 0xD800 && hexnum1 < 0xDBFF
            if next_char != '\\' || next_char != 'u'
              raise "Unterminated UTF-16 sequence"
            end
            hexnum2 = read_hex_number
            append_to_buffer (0x10000 | (hexnum1 & 0x3FF) << 10 | (hexnum2 & 0x3FF)).chr unless simple_string
          else
            append_to_buffer hexnum1.chr unless simple_string
          end
        else
          raise "uknown escape char: #{char}"
        end
      when '"'
        next_char
        break
      else
        append_to_buffer char unless simple_string
      end
    end
    @token.type = :STRING

    return if @skip

    if simple_string
      if @expects_object_key
        start_pos += 1
        end_pos = current_pos - 1
        @token.string_value = @string_pool.get(@reader.string.cstr + start_pos, end_pos - start_pos)
      else
        @token.string_value = string_range(start_pos + 1, current_pos - 1)
      end
    else
      if @expects_object_key
        @token.string_value = @string_pool.get(@buffer)
      else
        @token.string_value = buffer_contents
      end
    end
  end

  private def read_hex_number
    hexnum = 0
    4.times do
      char = next_char
      hexnum = (hexnum << 4) | char.to_i(16) { raise "unexpected char in hex number: #{char.inspect}" }
    end
    hexnum
  end

  private def consume_number
    integer = 0_i64
    negative = false

    if current_char == '-'
      negative = true
      next_char
    end

    if current_char == '0'
      next_char
      if current_char == '.'
        consume_float(negative, integer)
      elsif current_char == 'e'
        consume_exponent(negative, integer.to_f64)
      elsif '0' <= current_char <= '9' || current_char == 'e' || current_char == 'E'
        unexpected_char
      else
        @token.type = :INT
        @token.int_value = 0_i64
      end
    elsif '1' <= current_char <= '9'
      integer = (current_char.ord - '0'.ord).to_i64
      char = next_char
      while '0' <= char <= '9'
        integer *= 10
        integer += (char.ord - '0'.ord)
        char = next_char
      end

      case char
      when '.'
        consume_float(negative, integer)
      when 'e'
        consume_exponent(negative, integer.to_f64)
      else
        @token.type = :INT
        @token.int_value = negative ? -integer : integer
      end
    else
      unexpected_char
    end
  end

  private def consume_float(negative, integer)
    divisor = 1_u64
    char = next_char
    while '0' <= char <= '9'
      integer *= 10
      integer += (char.ord - '0'.ord)
      divisor *= 10
      char = next_char
    end
    float = integer.to_f64 / divisor

    if char == 'e' || char == 'E'
      consume_exponent(negative, float)
    else
      @token.type = :FLOAT
      @token.float_value = negative ? -float : float
    end
  end

  private def consume_exponent(negative, float)
    exponent = 0
    negative_exponent = false

    char = next_char
    if char == '+'
      char = next_char
    elsif char == '-'
      char = next_char
      negative_exponent = true
    end

    if '0' <= char <= '9'
      while '0' <= char <= '9'
        exponent *= 10
        exponent += (char.ord - '0'.ord)
        char = next_char
      end
    else
      unexpected_char
    end

    @token.type = :FLOAT

    exponent = -exponent if negative_exponent
    float *= (10_f64 ** exponent)
    @token.float_value = negative ? -float : float
  end

  private def current_pos
    @reader.pos
  end

  def string_range(start_pos, end_pos)
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  def slice_range(start_pos, end_pos)
    @reader.string.to_slice.to_slice[start_pos, end_pos - start_pos]
  end

  private def next_char
    @column_number += 1
    next_char_no_column_increment
  end

  private def next_char_no_column_increment
    @reader.next_char
  end

  private def next_char(token_type)
    @token.type = token_type
    next_char
  end

  private def current_char
    @reader.current_char
  end

  private def clear_buffer
    @buffer.clear
  end

  private def append_to_buffer(value)
    @buffer << value unless @skip
  end

  private def write_to_buffer(slice)
    @buffer.write slice
  end

  private def buffer_contents
    @buffer.to_s
  end

  private def unexpected_char(char = current_char)
    raise "unexpected char '#{char}'"
  end

  private def raise(msg)
    ::raise ParseException.new(msg, @line_number, @column_number)
  end
end
