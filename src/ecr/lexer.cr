# :nodoc:
class ECR::Lexer
  class Token
    property type : Symbol
    setter value : String
    property line_number : Int32
    property column_number : Int32

    def initialize
      @type = :EOF
      @value = ""
      @line_number = 0
      @column_number = 0
    end
    
    def suppress_leading?
      !!(@type == :CONTROL && @value.match /^-/)
    end
    
    def suppress_trailing?
      !!(@type == :CONTROL && @value.match /-$/)
    end

    def is_output?
      !!(@type == :CONTROL && @value.match /^=/)
    end
    
    def is_escape?
      !!(@type == :CONTROL && @value.match /^%/)
    end
    
    def is_whitespace?
      !!@value.match /^\s*$/
    end
    
    def val
      @value
    end

    def value
      value = @value
      if @type == :CONTROL
        value = value.sub(/^-/, "") if suppress_leading? 
        value = value.sub(/-$/, "") if suppress_trailing?
        value = value.sub(/^=/, "") if is_output? 
        value = value.sub(/^%(.*)/, "<%\\1%>") if is_escape?
        value = value.strip
      end
      value
    end
    
    def output
      return :STRING if is_escape?
      return :OUTPUT if is_output?
      @type
    end
    
    def append_value(str, buffer_name, filename)
      case output
      when :STRING
        str << buffer_name
        str << " << "
        value.inspect(str)
        str << "\n"
      when :OUTPUT
        str << "("
        append_loc(str, filename)
        str << value
        str << ").to_s "
        str << buffer_name
        str << "\n"
      when :CONTROL
        append_loc(str, filename)
        str << " " unless value.starts_with?(' ')
        str << value
        str << "\n"
      end
    end
    
    
    private def append_loc(str, filename)
      str << %(#<loc:")
      str << filename
      str << %(",)
      str << @line_number
      str << %(,)
      str << @column_number
      str << %(>)
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
        copy_location_info_to_token
        return consume_control
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
        next_char
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

  private def consume_control
    start_pos = current_pos
    while true
      case current_char
      when '\0'
        raise "unexpected end of file inside <% ..."
      when '\n'
        @line_number += 1
        @column_number = 0
      when '%'
        if peek_next_char == '>'
          @token.type = :CONTROL
          @token.value = string_range(start_pos)
          next_char
          next_char
          break
        end
      end
      next_char
    end

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
