class CSV::Parser
  def initialize(string)
    @reader = CharReader.new(string)
    @result = [] of Array(String)
    @row = [] of String
    @buffer = StringIO.new
    @column_number = 1
    @line_number = 1
  end

  def parse
    if current_char == '\0'
      return @result
    end

    has_quote = false

    while true
      case current_char
      when '\0'
        close_cell
        close_row
        break
      when ','
        close_cell
        next_char
      when '\n'
        @line_number += 1
        @column_number = 1
        close_cell
        close_row
        if next_char == '\0'
          break
        end
      when '"'
        if has_quote
          char = next_char
          if char == '"'
            @buffer << '"'
            next_char
            next
          end

          has_quote = false
          close_cell
          case char
          when ','
            next_char
          when '\n'
            close_row
            next_char
          when '\0'
            close_row
            break
          else
            raise "expecting comma, newline or end, not #{char.inspect}"
          end
        else
          if @buffer.empty?
            has_quote = true
            next_char
          else
            raise "unexpected quote"
          end
        end
      else
        @buffer << current_char
        next_char
      end
    end

    @result
  end

  private def close_cell
    @row.push @buffer.to_s
    @buffer.clear
  end

  private def close_row
    @result.push @row.dup
    @row.clear
  end

  private def next_char
    @column_number += 1
    @reader.next_char
  end

  private def current_char
    @reader.current_char
  end

  private def raise(msg)
    ::raise CSV::MalformedCSVError.new(msg, @line_number, @column_number)
  end
end
