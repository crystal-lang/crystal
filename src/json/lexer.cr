class Json::Lexer
  def initialize(string)
    @reader = CharReader.new(string)
    @token = Token.new
    @line_number = 1
    @column_number = 1
    @string_io = StringIO.new
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
    @string_io.clear
    buffer = @string_io
    while true
      case char = next_char
      when '\0'
        raise "unterminated string"
      when '\\'
        case char = next_char
        when '\\', '"', '/'
          buffer << char
        when 'b'
          buffer << '\b'
        when 'f'
          buffer << '\f'
        when 'n'
          buffer << '\n'
        when 'r'
          buffer << '\r'
        when 't'
          buffer << '\t'
        when 'u'
          hexnum1 = read_hex_number
          if hexnum1 > 0xD800 && hexnum1 < 0xDBFF
            if next_char != '\\' || next_char != 'u'
              raise "Unterminated UTF-16 sequence"
            end
            hexnum2 = read_hex_number
            buffer << (0x10000 | (hexnum1 & 0x3FF) << 10 | (hexnum2 & 0x3FF)).chr
          else
            buffer << hexnum1.chr
          end
        else
          raise "uknown escape char: #{char}"
        end
      when '"'
        next_char
        break
      else
        buffer << char
      end
    end
    @token.type = :STRING
    @token.string_value = buffer.to_s
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
    divisor = 1
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

  private def unexpected_char(char = current_char)
    raise "unexpected char '#{char}'"
  end

  private def raise(msg)
    ::raise ParseException.new(msg, @line_number, @column_number)
  end
end
