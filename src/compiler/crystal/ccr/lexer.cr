module Crystal::CCR
  class Lexer
    class Token
      enum Kind
        String
        Control
        EOF
      end

      property type : Kind
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

    def initialize(string : String)
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
            return consume_control
          else
            raise "expected '='"
          end
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

      @token.type = :string
      @token.value = string_range(start_pos)
      @token
    end

    private def consume_control
      start_pos = current_pos
      while true
        case current_char
        when '\0'
          raise "Unexpected end of file inside <%= ..."
        when '\n'
          @line_number += 1
          @column_number = 0
        when '%'
          if peek_next_char == '>'
            setup_control_token(start_pos)
            break
          end
        end
        next_char
      end

      @token.type = :control
      @token
    end

    private def setup_control_token(start_pos)
      @token.value = string_range(start_pos).strip
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
end
