class CSV::Parser
  def initialize(string_or_io)
    @lexer = CSV::Lexer.new(string_or_io)
    @max_row_length = 3
  end

  def parse
    rows = [] of Array(String)
    each_row { |row| rows << row }
    rows
  end

  def each_row
    while row = next_row
      yield row
    end
  end

  def next_row
    token = @lexer.next_token
    if token.kind == :eof
      return nil
    end

    row = Array(String).new(@max_row_length)
    while true
      case token.kind
      when :cell
        row << token.value
        token = @lexer.next_token
      else #:newline, :eof
        @max_row_length = row.length if row.length > @max_row_length
        return row
      end
    end
  end
end
