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

  def each_row
    RowIterator.new(self)
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

  def rewind
    @lexer.rewind
  end

  # :nodoc:
  struct RowIterator
    include Iterator(Array(String))

    def initialize(@parser)
    end

    def next
      @parser.next_row || stop
    end

    def rewind
      @parser.rewind
    end
  end
end
