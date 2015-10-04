# A CSV parser. It lets you consume a CSV row by row.
#
# Most of the time `CSV#parse` and `CSV#each_row` are more convenient.
class CSV::Parser
  # Creates a parser from a `String` or `IO`.
  def initialize(string_or_io : String | IO, header_row = false)
    @lexer = CSV::Lexer.new(string_or_io)
    @max_row_size = 3
    @header_row = header_row
    @header = [] of String
  end

  # Returns the remaining rows.
  def parse : Array(Array(String)) | Array(Hash(String,String))
    if @header_row == true
      rows = [] of Hash(String,String)
      each_row_with_header{ |row| rows << row }
    else
      rows = [] of Array(String)
      each_row { |row| rows << row }
    end
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

    row = Array(String).new(@max_row_size)
    while true
      case token.kind
      when Token::Kind::Cell
        row << token.value
        token = @lexer.next_token
      else #:newline, :eof
        @max_row_size = row.size if row.size > @max_row_size
        return row
      end
    end
  end

  def parse_header
    if @header.size > 0
      return @header
    end

    temp_header = [] of String
    while @header.size == 0
      token = @lexer.next_token
      if token.kind == Token::Kind::Eof || token.kind == Token::Kind::Newline
        break
      end
      temp_header << token.value
    end
    @header = temp_header
  end

  # Yields each of the remaining rows as `Array(Hash(String, String))`.
  def each_row_with_header
    parse_header
    while row_with_header = next_row_with_header
      yield row_with_header
    end
  end

  # Returns an `Iterator` of `Array(Hash(String, String))` for the remaining rows.
  def each_row_with_header
    parse_header
    RowWithHeaderIterator.new(self)
  end

  # Returns the next row with header in the CSV, if any, or `nil`.
  def next_row_with_header : Hash(String, String) | Nil
    parse_header
    token = @lexer.next_token
    if token.kind == Token::Kind::Eof
      return nil
    end

    row = {} of String => String 
    field_index = 0
    while true
      case token.kind
      when Token::Kind::Cell
        row[@header[field_index]] = token.value
        token = @lexer.next_token
        field_index += 1
      else #:newline, :eof
        @max_row_size = row.size if row.size > @max_row_size
        return row
      end
    end
  end  

  # Rewinds this parser to the first row.
  def rewind
    @lexer.rewind

    # If we heave a header row we want to rewind to the first non-header row
    if @header_row == true
      skipped_header = false
      while skipped_header == false
        token = @lexer.next_token
        if token.kind == Token::Kind::Eof || token.kind == Token::Kind::Newline
          skipped_header = true
          break
        end
      end
    end
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

  # :nodoc:
  struct RowWithHeaderIterator
    include Iterator(Hash(String, String))

    def initialize(@parser)
    end

    def next
      @parser.next_row_with_header || stop
    end

    def rewind
      @parser.rewind
    end
  end
end
