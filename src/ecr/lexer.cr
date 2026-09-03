# :nodoc:
class ECR::Lexer
  class Token
    enum Type
      String
      Output
      Control
      EOF
    end

    property type : Type
    property value : String
    property line_number : Int32
    property column_number : Int32
    property? suppress_leading : Bool
    property? suppress_trailing : Bool

    def initialize
      @type = :EOF
      @value = ""
      @line_number = 0
      @column_number = 0
      @suppress_leading = false
      @suppress_trailing = false
    end
  end

  class SyntaxException < Exception
    getter line_number : Int32
    getter column_number : Int32

    def initialize(message, @line_number, @column_number)
      super(message)
    end
  end

  def initialize(string)
    @reader = Char::Reader.new(string)
    @token = Token.new
    @line_number = 1
    @column_number = 1
  end

  def next_token : Token
    copy_location_info_to_token

    case current_char
    when '\0'
      @token.type = :EOF
      return @token
    when '<'
      if peek_next_char == '%'
        next_char
        next_char

        suppress_leading = current_char == '-'
        next_char if suppress_leading

        case current_char
        when '='
          next_char
          copy_location_info_to_token
          is_output = true
        when '%'
          next_char
          copy_location_info_to_token
          is_escape = true
        else
          copy_location_info_to_token
        end

        return consume_control(is_output, is_escape, suppress_leading)
      end
    else
      # consume string
    end

    consume_string
  end

  private def consume_string
    start_pos = current_pos
    while true
      case current_char
      when '\0'
        break
      when '\n'
        @line_number += 1
        @column_number = 0
      when '<'
        if peek_next_char == '%'
          break
        end
      else
        # keep going
      end
      next_char
    end

    @token.type = :string
    @token.value = string_range(start_pos)
    @token
  end

  private def consume_control(is_output, is_escape, suppress_leading)
    start_pos = current_pos
    while true
      case current_char
      when '\0'
        if is_output
          raise "Unexpected end of file inside <%= ..."
        elsif is_escape
          raise "Unexpected end of file inside <%% ..."
        else
          raise "Unexpected end of file inside <% ..."
        end
      when '\n'
        @line_number += 1
        @column_number = 0
      when '-'
        if peek_next_char == '%'
          # We need to peek another char, so we remember
          # where we are, check that, and then go back
          pos = @reader.pos
          column_number = @column_number

          next_char

          is_end = peek_next_char == '>'
          @reader.pos = pos
          @column_number = column_number

          if is_end
            setup_control_token(start_pos, is_escape, suppress_leading, true)
            raise "Expecting '>' after '-%'" if current_char != '>'
            next_char
            break
          end
        end
      when '%'
        if peek_next_char == '>'
          setup_control_token(start_pos, is_escape, suppress_leading, false)
          break
        end
      else
        # keep going
      end
      next_char
    end

    if is_escape
      @token.type = :string
    elsif is_output
      @token.type = :output
    else
      @token.type = :control
    end
    @token
  end

  private def setup_control_token(start_pos, is_escape, suppress_leading, suppress_trailing)
    @token.suppress_leading = !is_escape && suppress_leading
    @token.suppress_trailing = !is_escape && suppress_trailing
    @token.value =
      if is_escape
        head = suppress_leading ? "<%-" : "<%"
        tail = string_range(start_pos, current_pos + (suppress_trailing ? 3 : 2))
        head + tail
      else
        string_range(start_pos)
      end

    next_char
    next_char
  end

  private def copy_location_info_to_token
    @token.line_number = @line_number
    @token.column_number = @column_number
  end

  private def current_char
    @reader.current_char
  end

  private def next_char
    @column_number += 1
    next_char_no_column_increment
  end

  private def next_char_no_column_increment
    @reader.next_char
  end

  private def peek_next_char
    @reader.peek_next_char
  end

  private def current_pos
    @reader.pos
  end

  private def string_range(start_pos)
    string_range(start_pos, current_pos)
  end

  private def string_range(start_pos, end_pos)
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  private def raise(message : String)
    raise SyntaxException.new(message, @line_number, @column_number)
  end
end
