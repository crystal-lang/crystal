# A CSV parser. It lets you consume a CSV row by row.
#
# Most of the time `CSV#parse` and `CSV#each_row` are more convenient.
class CSV::Parser
  # Creates a parser from a `String` or `IO`.
  def initialize(string_or_io : String | IO)
    @lexer = CSV::Lexer.new(string_or_io)
    @max_row_length = 3
  end

  # Returns the remaining rows.
  def parse : Array(Array(String))
    rows = [] of Array(String)
    each_row { |row| rows << row }
    rows
  end

  # Yields each of the reamining rows as an `Array(String)`.
  def each_row
    while row = next_row
      yield row
    end
  end

  # Returns an `Iterator` of `Array(String)` for the remaining rows.
  def each_row
    RowIterator.new(self)
  end

  # Returns the next row in the CSV, if any, or `nil`.
  def next_row : Array(String) | Nil
    token = @lexer.next_token
    if token.kind == Token::Kind::Eof
      return nil
    end

    row = Array(String).new(@max_row_length)
    while true
      case token.kind
      when Token::Kind::Cell
        row << token.value
        token = @lexer.next_token
      else #:newline, :eof
        @max_row_length = row.length if row.length > @max_row_length
        return row
      end
    end
  end

  # Rewinds this parser to the first row.
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
