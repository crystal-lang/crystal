require "string_pool"

abstract class JSON::Lexer
  def self.new(string : String)
    StringBased.new(string)
  end

  def self.new(io : IO)
    IOBased.new(io)
  end

  getter token : Token
  property skip : Bool

  def initialize
    @token = Token.new
    @line_number = 1
    @column_number = 1
    @buffer = IO::Memory.new
    @string_pool = StringPool.new
    @skip = false
    @expects_object_key = false
  end

  private abstract def consume_string
  private abstract def next_char_no_column_increment
  private abstract def current_char
  private abstract def number_start
  private abstract def append_number_char
  private abstract def number_string

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
      @token.type = :STRING
      @skip ? consume_string_skip : consume_string
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
    while whitespace?(current_char)
      if current_char == '\n'
        @line_number += 1
        @column_number = 0
      end
      next_char
    end
  end

  private def whitespace?(char)
    case char
    when ' ', '\t', '\n', '\r'
      true
    else
      false
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

  # Since we are skipping we don't care about a
  # string's contents, so we just move forward.
  private def consume_string_skip
    while true
      case next_char
      when '\0'
        raise "Unterminated string"
      when '\\'
        consume_string_escape_sequence
      when '"'
        next_char
        break
      else
        if 0 <= current_char.ord < 32
          unexpected_char
        end
      end
    end
  end

  private def consume_string_with_buffer
    consume_string_with_buffer { }
  end

  private def consume_string_with_buffer
    @buffer.clear
    yield
    while true
      case char = next_char
      when '\0'
        raise "Unterminated string"
      when '\\'
        @buffer << consume_string_escape_sequence
      when '"'
        next_char
        break
      else
        if 0 <= current_char.ord < 32
          unexpected_char
        else
          @buffer << char
        end
      end
    end
    if @expects_object_key
      @token.string_value = @string_pool.get(@buffer)
    else
      @token.string_value = @buffer.to_s
    end
  end

  private def consume_string_escape_sequence
    case char = next_char
    when '\\', '"', '/'
      char
    when 'b'
      '\b'
    when 'f'
      '\f'
    when 'n'
      '\n'
    when 'r'
      '\r'
    when 't'
      '\t'
    when 'u'
      hexnum1 = read_hex_number
      if hexnum1 > 0xD800 && hexnum1 < 0xDBFF
        if next_char != '\\' || next_char != 'u'
          raise "Unterminated UTF-16 sequence"
        end
        hexnum2 = read_hex_number
        (0x10000 | (hexnum1 & 0x3FF) << 10 | (hexnum2 & 0x3FF)).chr
      else
        hexnum1.chr
      end
    else
      raise "Unknown escape char: #{char}"
    end
  end

  private def read_hex_number
    hexnum = 0
    4.times do
      char = next_char
      hexnum = (hexnum << 4) | (char.to_i?(16) || raise "Unexpected char in hex number: #{char.inspect}")
    end
    hexnum
  end

  private def consume_number
    number_start

    integer = 0_i64
    negative = false
    digits = 0

    if current_char == '-'
      append_number_char
      negative = true
      next_char
    end

    case current_char
    when '0'
      append_number_char
      next_char
      case current_char
      when '.'
        consume_float(negative, integer, digits)
      when 'e', 'E'
        consume_exponent(negative, integer.to_f64, digits)
      when '0'..'9'
        unexpected_char
      else
        @token.type = :INT
        @token.int_value = 0_i64
        number_end
      end
    when '1'..'9'
      digits = 1
      append_number_char
      integer = (current_char - '0').to_i64
      char = next_char
      while '0' <= char <= '9'
        append_number_char
        integer *= 10
        integer += char - '0'
        digits += 1
        char = next_char
      end

      case char
      when '.'
        consume_float(negative, integer, digits)
      when 'e', 'E'
        consume_exponent(negative, integer.to_f64, digits)
      else
        @token.type = :INT
        @token.int_value = negative ? -integer : integer
        number_end
      end
    else
      unexpected_char
    end
  end

  private def consume_float(negative, integer, digits)
    append_number_char
    divisor = 1_u64
    char = next_char

    unless '0' <= char <= '9'
      unexpected_char
    end

    while '0' <= char <= '9'
      append_number_char
      integer *= 10
      integer += char - '0'
      divisor *= 10
      digits += 1
      char = next_char
    end
    float = integer.to_f64 / divisor

    if char == 'e' || char == 'E'
      consume_exponent(negative, float, digits)
    else
      @token.type = :FLOAT
      # If there's a chance of overflow, we parse the raw string
      if digits >= 18
        @token.float_value = number_string.to_f64
      else
        @token.float_value = negative ? -float : float
      end
      number_end
    end
  end

  private def consume_exponent(negative, float, digits)
    append_number_char
    exponent = 0
    negative_exponent = false

    char = next_char
    if char == '+'
      append_number_char
      char = next_char
    elsif char == '-'
      append_number_char
      char = next_char
      negative_exponent = true
    end

    if '0' <= char <= '9'
      while '0' <= char <= '9'
        append_number_char
        exponent *= 10
        exponent += char - '0'
        char = next_char
      end
    else
      unexpected_char
    end

    @token.type = :FLOAT

    exponent = -exponent if negative_exponent
    float *= (10_f64 ** exponent)

    # If there's a chance of overflow, we parse the raw string
    if digits >= 18
      @token.float_value = number_string.to_f64
    else
      @token.float_value = negative ? -float : float
    end

    number_end
  end

  private def next_char
    @column_number += 1
    next_char_no_column_increment
  end

  private def next_char(token_type)
    @token.type = token_type
    next_char
  end

  private def number_end
    @token.raw_value = number_string
  end

  private def unexpected_char(char = current_char)
    raise "Unexpected char '#{char}'"
  end

  private def raise(msg)
    ::raise ParseException.new(msg, @line_number, @column_number)
  end
end

require "./lexer/*"
