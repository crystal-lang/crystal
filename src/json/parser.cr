class Json::Parser
  def initialize(string)
    @lexer = Lexer.new(string)
    @token = @lexer.next_token
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
