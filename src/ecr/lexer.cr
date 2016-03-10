# :nodoc:
class ECR::Lexer
  class Token
    property type : Symbol
    property value : String
    property line_number : Int32
    property column_number : Int32

    def initialize
      @type = :EOF
      @value = ""
      @line_number = 0
      @column_number = 0
    end
  end

  @reader : Char::Reader
  @token : Token
  @line_number : Int32
  @column_number : Int32

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
          raise "unexpected end of file inside <%= ..."
        elsif is_escape
          raise "unexpected end of file inside <%% ..."
        else
          raise "unexpected end of file inside <% ..."
        end
      when '\n'
        @line_number += 1
        @column_number = 0
      when '%'
        if peek_next_char == '>'
          @token.value = if is_escape
                           "<%#{string_range(start_pos, current_pos + 2)}"
                         else
                           string_range(start_pos)
                         end
          next_char
          next_char
          break
        end
      end
      next_char
    end

    @token.type = is_escape ? :STRING : (is_output ? :OUTPUT : :CONTROL)
    @token
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
