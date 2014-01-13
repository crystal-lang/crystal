module Json
  class ParseException < ::Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  class Token
    property :type
    property :string_value
    property :int_value
    property :float_value
    property :line_number
    property :column_number

    def initialize
      @type = :EOF
      @line_number = 0
      @column_number = 0
      @string_value = ""
      @int_value = 0_i64
      @float_value = 0.0
    end

    def to_s
      case @type
      when :INT
        @int_value.to_s
      when :FLOAT
        @float_value.to_s
      when :STRING
        @string_value
      else
        @type.to_s
      end
    end
  end

  class Lexer
    def initialize(string)
      @buffer = string.cstr
      @token = Token.new
      @line_number = 1
      @column_number = 1
      @string_buffer = String::Buffer.new
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

    def skip_whitespace
      while current_char.whitespace?
        if current_char == '\n'
          @line_number += 1
          @column_number = 0
        end
        next_char
      end
    end

    def consume_true
      if next_char == 'r' && next_char == 'u' && next_char == 'e'
        next_char
        @token.type = :true
      else
        unexpected_char
      end
    end

    def consume_false
      if next_char == 'a' && next_char == 'l' && next_char == 's' && next_char == 'e'
        next_char
        @token.type = :false
      else
        unexpected_char
      end
    end

    def consume_null
      if next_char == 'u' && next_char == 'l' && next_char == 'l'
        next_char
        @token.type = :null
      else
        unexpected_char
      end
    end

    def consume_string
      @string_buffer.clear
      buffer = @string_buffer
      while true
        char = next_char
        case char
        when '\0'
          raise "unterminated string"
        when '\\'
          char = next_char
          case char
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
          # TODO when 'u'
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

    def consume_number
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

    def consume_float(negative, integer)
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

    def consume_exponent(negative, float)
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

    def next_char
      @column_number += 1
      next_char_no_column_increment
    end

    def next_char_no_column_increment
      @buffer += 1
      current_char
    end

    def next_char(token_type)
      @token.type = token_type
      next_char
    end

    def current_char
      @buffer.value
    end

    def unexpected_char(char = current_char)
      raise "unexpected char '#{char}'"
    end

    def raise(msg)
      ::raise ParseException.new(msg, @line_number, @column_number)
    end
  end

  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Type) | Hash(String, Type)

  class Parser
    def initialize(string)
      @lexer = Lexer.new(string)
      @token = next_token
    end

    def parse
      json = parse_array_or_object
      check :EOF
      json
    end

    def parse_array_or_object
      case @token.type
      when :"["
        parse_array
      when :"{"
        parse_object
      else
        unexpected_token
      end
    end

    def parse_array
      next_token

      ary = [] of Type

      if @token.type != :"]"
        while true
          ary << parse_value

          case @token.type
          when :","
            next_token
            unexpected_token if @token.type == :"]"
          when :"]"
            break
          end
        end
      end

      next_token

      ary
    end

    def parse_object
      next_token

      object = {} of String => Type

      if @token.type != :"}"
        while true
          check :STRING
          key = @token.string_value

          next_token

          check :":"
          next_token

          value = parse_value

          object[key] = value

          case @token.type
          when :","
            next_token
            unexpected_token if @token.type == :"}"
          when :"}"
            break
          end
        end
      end

      next_token

      object
    end

    def parse_value
      case @token.type
      when :INT
        value_and_next_token @token.int_value
      when :FLOAT
        value_and_next_token @token.float_value
      when :STRING
        value_and_next_token @token.string_value
      when :null
        value_and_next_token nil
      when :true
        value_and_next_token true
      when :false
        value_and_next_token false
      else
        parse_array_or_object
      end
    end

    def value_and_next_token(value)
      next_token
      value
    end

    def check(token_type)
      unexpected_token unless @token.type == token_type
    end

    def next_token
      @token = @lexer.next_token
    end

    def unexpected_token
      raise ParseException.new("unexpected token '#{@token}'", @token.line_number, @token.column_number)
    end
  end

  def self.parse(string)
    Parser.new(string).parse
  end
end
