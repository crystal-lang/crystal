# :nodoc:
class ECR::Lexer
  class Token
    property type : Symbol
    property value : String
    property line_number : Int32
    property column_number : Int32
    property? supress_leading : Bool
    property? supress_trailing : Bool

    def initialize
      @type = :EOF
      @value = ""
      @line_number = 0
      @column_number = 0
      @supress_leading = false
      @supress_trailing = false
    end
  end

  def initialize(string)
    @reader = Char::Reader.new(string)
    @token = Token.new
    @line_number = 1
    @column_number = 1
  end

  def next_token
    copy_location_info_to_token

    case current_char
    when '\0'
      @token.type = :EOF
      return @token
    when '<'
      if peek_next_char == '%'
        next_char
        next_char

        if current_char == '-'
          @token.supress_leading = true
          next_char
        else
          @token.supress_leading = false
        end

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

        return consume_control(is_output, is_escape)
      end
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
      end
      next_char
    end

    @token.type = :STRING
    @token.value = string_range(start_pos)
    @token
  end

  private def consume_control(is_output, is_escape)
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
            @token.supress_trailing = true
            setup_control_token(start_pos, is_escape)
            raise "Expecting '>' after '-%'" if current_char != '>'
            next_char
            break
          end
        end
      when '%'
        if peek_next_char == '>'
          @token.supress_trailing = false
          setup_control_token(start_pos, is_escape)
          break
        end
      end
      next_char
    end

    @token.type = is_escape ? :STRING : (is_output ? :OUTPUT : :CONTROL)
    @token
  end

  private def setup_control_token(start_pos, is_escape)
    @token.value = if is_escape
                     "<%#{string_range(start_pos, current_pos + 2)}"
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
end
