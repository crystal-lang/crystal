module Json
  class ParseException < ::Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super(message)
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
    end

    def next_token
      # Skip whitespaces
      while @buffer.value.whitespace?
        if @buffer.value == '\n'
          @line_number += 1
          @column_number = 0
        end
        next_char
      end

      @token.line_number = @line_number
      @token.column_number = @column_number

      case @buffer.value
      when '\0'
        @token.type = :EOF
      when '{'
        next_char
        @token.type = :"{"
      when '}'
        next_char
        @token.type = :"}"
      when '['
        next_char
        @token.type = :"["
      when ']'
        next_char
        @token.type = :"]"
      when ','
        next_char
        @token.type = :","
      when ':'
        next_char
        @token.type = :":"
      when 'f'
        if next_char == 'a' && next_char == 'l' && next_char == 's' && next_char == 'e'
          next_char
          @token.type = :false
        else
          unexpected_char
        end
      when 'n'
        if next_char == 'u' && next_char == 'l' && next_char == 'l'
          next_char
          @token.type = :null
        else
          unexpected_char
        end
      when 't'
        if next_char == 'r' && next_char == 'u' && next_char == 'e'
          next_char
          @token.type = :true
        else
          unexpected_char
        end
      when '"'
        buffer = String::Buffer.new
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
              raise ParseException.new("uknown escape char: #{char}", @line_number, @column_number)
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
      else
        start = @buffer
        count = 1

        if @buffer.value == '-'
          count += 1
          next_char
        end

        if @buffer.value == '0'
          if @buffer[1] == '.'
            next_char
            count += 1
            consume_float(start, count)
          elsif @buffer[1] == 'e'
            next_char
            consume_exponent(start, 2)
          elsif '0' <= @buffer[1] <= '9' || @buffer[1] == 'e' || @buffer[1] == 'E'
            unexpected_char
          else
            next_char
            @token.type = :INT
            @token.int_value = 0_i64
          end
        elsif '1' <= @buffer.value <= '9'
          char = next_char
          while '0' <= char <= '9'
            count += 1
            char = next_char
          end

          case char
          when '.'
            count += 1
            consume_float(start, count)
          when 'e'
            consume_exponent(start, count)
          else
            @token.type = :INT
            @token.int_value = String.new(start, count).to_i64
          end
        else
          unexpected_char
        end
      end

      @token
    end

    def consume_float(start, count)
      char = next_char
      while '0' <= char <= '9'
        count += 1
        char = next_char
      end

      if char == 'e' || char == 'E'
        consume_exponent(start, count)
      else
        @token.type = :FLOAT
        @token.float_value = String.new(start, count).to_f
      end
    end

    def consume_exponent(start, count)
      count += 1
      char = next_char
      if char == '+' || char == '-'
        char = next_char
        count += 1
      end

      if '0' <= char <= '9'
        count += 1
        char = next_char
        while '0' <= char <= '9'
          count += 1
          char = next_char
        end
      else
        unexpected_char
      end

      @token.type = :FLOAT
      @token.float_value = String.new(start, count).to_f
    end

    def next_char
      @column_number += 1
      next_char_no_column_increment
    end

    def next_char_no_column_increment
      @buffer += 1
      @buffer.value
    end

    def unexpected_char(char = @buffer.value)
      raise ParseException.new("unexpected char: #{char}", @line_number, @column_number)
    end
  end

  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Type) | Hash(String, Type)

  class Parser < Lexer
    def parse
      next_token
      parse_array_or_object
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

      while @token.type != :"]"
        ary << parse_value

        if @token.type == :","
          next_token
          unexpected_token if @token.type == :"]"
        end
      end

      next_token

      ary
    end

    def parse_object
      next_token

      object = {} of String => Type

      while @token.type != :"}"
        check :STRING
        key = @token.string_value

        next_token

        check :":"
        next_token

        value = parse_value

        object[key] = value

        if @token.type == :","
          next_token
          unexpected_token if @token.type == :"}"
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

    def unexpected_token
      raise ParseException.new("unexpected token: #{@token}", @token.line_number, @token.column_number)
    end
  end

  def self.parse(string)
    Parser.new(string).parse
  end
end
