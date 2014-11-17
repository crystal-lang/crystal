abstract class CSV::Lexer
  def self.new(string : String)
    StringBased.new(string)
  end

  def self.new(io : IO)
    IOBased.new(io)
  end

  getter token

  def initialize
    @token = Token.new
    @buffer = StringIO.new
    @column_number = 1
    @line_number = 1
    @last_empty_column = false
  end

  private abstract def consume_unquoted_cell
  private abstract def next_char_no_column_increment
  private abstract def current_char

  def next_token
    if @last_empty_column
      @last_empty_column = false
      @token.kind = :cell
      @token.value = ""
      return @token
    end

    case current_char
    when '\0'
      @token.kind = :eof
    when ','
      @token.kind = :cell
      @token.value = ""
      check_last_empty_column
    when '\n'
      @token.kind = next_char == '\0' ? :eof : :newline
    when '"'
      @token.kind = :cell
      @token.value = consume_quoted_cell
    else
      @token.kind = :cell
      @token.value = consume_unquoted_cell
    end
    @token
  end

  private def consume_quoted_cell
    @buffer.clear
    while true
      case char = next_char
      when '\0'
        raise "unclosed quote"
        break
      when '"'
        case next_char
        when ','
          check_last_empty_column
          break
        when '\n', '\0'
          break
        when '"'
          @buffer << '"'
        else
          raise "expecting comma, newline or end, not #{current_char.inspect}"
        end
      else
        @buffer << char
      end
    end
    @buffer.to_s
  end

  private def check_last_empty_column
    case next_char
    when '\n', '\0'
      @last_empty_column = true
    end
  end

  private def next_char
    @column_number += 1
    char = next_char_no_column_increment
    if char == '\n'
      @column_number = 0
      @line_number += 1
    end
    char
  end

  private def raise(msg)
    ::raise CSV::MalformedCSVError.new(msg, @line_number, @column_number)
  end
end
