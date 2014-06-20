class ECR::Lexer
  class Token
    property :type
    property :value

    def initialize
      @type = :EOF
      @value = ""
    end
  end

  def initialize(string)
    @reader = CharReader.new(string)
    @token = Token.new
  end

  def next_token
    case current_char
    when '\0'
      @token.type = :EOF
      return @token
    when '<'
      if peek_next_char == '%'
        next_char
        next_char
        if current_char == '='
          is_output = true
          next_char
        else
          is_output = false
        end

        return consume_control(is_output)
      end
    end

    consume_string
  end

  def consume_string
    start_pos = current_pos
    while true
      case current_char
      when '\0'
        break
      when '<'
        if peek_next_char == '%'
          break
        end
      end
      next_char
    end

    @token.type = :STRING
    @token.value = string_range(start_pos)
    @token
  end

  def consume_control(is_output)
    start_pos = current_pos
    while true
      case current_char
      when '\0'
        if is_output
          raise "unexpected end of file inside <%= ..."
        else
          raise "unexpected end of file inside <% ..."
        end
      when '%'
        if peek_next_char == '>'
          @token.value = string_range(start_pos)
          next_char
          next_char
          break
        end
      end
      next_char
    end

    @token.type = is_output ? :OUTPUT : :CONTROL
    @token
  end

  def current_char
    @reader.current_char
  end

  def next_char
    @reader.next_char
  end

  def peek_next_char
    @reader.peek_next_char
  end

  def current_pos
    @reader.pos
  end

  def string_range(start_pos)
    string_range(start_pos, current_pos)
  end

  def string_range(start_pos, end_pos)
    @reader.string[start_pos, end_pos - start_pos]
  end
end
