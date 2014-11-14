class CSV::Lexer::StringBased < CSV::Lexer
  def initialize(string)
    super()
    @reader = CharReader.new(string)
    if @reader.current_char == '\n'
      @line_number += 1
      @column_number = 0
    end
  end

  private def consume_unquoted_cell
    start_pos = @reader.pos
    end_pos = start_pos
    while true
      case next_char
      when ','
        end_pos = @reader.pos
        check_last_empty_column
        break
      when '\n', '\0'
        end_pos = @reader.pos
        break
      when '"'
        raise "unexpected quote"
      end
    end
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  private def next_char_no_column_increment
    @reader.next_char
  end

  private def current_char
    @reader.current_char
  end
end
