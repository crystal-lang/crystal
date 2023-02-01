require "csv"

# A CSV Builder writes CSV to an `IO`.
#
# ```
# require "csv"
#
# result = CSV.build do |csv|
#   # A row can be written by specifying several values
#   csv.row "Hello", 1, 'a', "String with \"quotes\"", '"', :sym
#
#   # Or an enumerable
#   csv.row [1, 2, 3]
#
#   # Or using a block, and appending to the row
#   csv.row do |row|
#     # Appending a single value
#     row << 4
#
#     # Or multiple values
#     row.concat 5, 6
#
#     # Or an enumerable
#     row.concat [7, 8]
#   end
# end
# puts result
# ```
#
# Output:
#
# ```text
# Hello,1,a,"String with ""quotes""","""",sym
# 1,2,3
# 4,5,6,7,8
# ```
class CSV::Builder
  enum Quoting
    # No quotes
    NONE

    # Quotes according to RFC 4180 (default)
    RFC

    # Always quote
    ALL
  end

  # Creates a builder that will write to the given `IO`.
  def initialize(@io : IO, @separator : Char = DEFAULT_SEPARATOR, @quote_char : Char = DEFAULT_QUOTE_CHAR, @quoting : Quoting = Quoting::RFC)
    @first_cell_in_row = true
  end

  # Yields a `CSV::Row` to append a row. A newline is appended
  # to `IO` after the block exits.
  def row(&)
    yield Row.new(self, @separator, @quote_char, @quoting)
    @io << '\n'
    @first_cell_in_row = true
  end

  # Appends the given values as a single row, and then a newline.
  def row(values : Enumerable) : Nil
    row do |row|
      values.each do |value|
        row << value
      end
    end
  end

  # :ditto:
  def row(*values) : Nil
    row values
  end

  # :nodoc:
  def cell(&)
    append_cell do
      yield @io
    end
  end

  # :nodoc:
  def quote_cell(value : String)
    append_cell do
      @io << @quote_char
      value.each_char do |char|
        case char
        when @quote_char
          @io << @quote_char << @quote_char
        else
          @io << char
        end
      end
      @io << @quote_char
    end
  end

  private def append_cell(&)
    @io << @separator unless @first_cell_in_row
    yield
    @first_cell_in_row = false
  end

  # A CSV Row being built.
  struct Row
    @builder : Builder

    # :nodoc:
    def initialize(@builder, @separator : Char = DEFAULT_SEPARATOR, @quote_char : Char = DEFAULT_QUOTE_CHAR, @quoting : Quoting = Quoting::RFC)
    end

    # Appends the given value to this row.
    def <<(value : String) : Nil
      if needs_quotes?(value)
        @builder.quote_cell value
      else
        @builder.cell { |io| io << value }
      end
    end

    # :ditto:
    def <<(value : Nil | Bool | Number) : Nil
      case @quoting
      when .all?
        @builder.cell { |io|
          io << @quote_char
          io << value
          io << @quote_char
        }
      else
        @builder.cell { |io| io << value }
      end
    end

    # :ditto:
    def <<(value) : Nil
      self << value.to_s
    end

    # Appends the given values to this row.
    def concat(values : Enumerable) : Nil
      values.each do |value|
        self << value
      end
    end

    # :ditto:
    def concat(*values) : Nil
      concat values
    end

    # Appends a comma, thus skipping a cell.
    def skip_cell : Nil
      self << nil
    end

    private def needs_quotes?(value : String)
      case @quoting
      when .rfc?
        value.each_byte do |byte|
          case byte.unsafe_chr
          when @separator, @quote_char, '\n'
            return true
          else
            # keep scanning
          end
        end
        false
      when .all?
        true
      else
        false
      end
    end
  end
end
