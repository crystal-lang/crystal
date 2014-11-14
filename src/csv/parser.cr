class CSV::Parser
  def initialize(string_or_io)
    @lexer = CSV::Lexer.new(string_or_io)
  end

  def parse
    rows = [] of Array(String)
    each_row { |row| rows << row }
    rows
  end

  def each_row
    token = @lexer.next_token
    if token.kind == :eof
      return
    end

    row = [] of String
    while true
      case token.kind
      when :cell
        row << token.value
        token = @lexer.next_token
      when :newline
        yield row.dup
        row.clear
        token = @lexer.next_token
        break if token.kind == :eof
      when :eof
        yield row.dup
        break
      end
    end
  end
end
