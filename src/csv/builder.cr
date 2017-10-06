require "csv"

# A CSV Builder writes CSV to an `IO`.
#
# ```
# require "csv"
#
# result = CSV.build do |csv|
#   # A row can be written by specifying several values
#   csv.row "Hello", 1, 'a', "String with \"quotes\""
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
# Hello,1,a,"String with ""quotes"""
# 1,2,3
# 4,5,6,7,8
# ```
class CSV::Builder
  # Creates a builder that will write to the given `IO`.
  def initialize(@io : IO)
    @first_cell_in_row = true
  end

  # Yields a `CSV::Row` to append a row. A newline is appended
  # to `IO` after the block exits.
  def row
    yield Row.new(self)
    @io << "\n"
    @first_cell_in_row = true
  end

  # Appends the given values as a single row, and then a newline.
  def row(values : Enumerable)
    row do |row|
      values.each do |value|
        row << value
      end
    end
  end

  # ditto
  def row(*values)
    row values
  end

  # :nodoc:
  def cell
    append_cell do
      yield @io
    end
  end

  # :nodoc:
  def quote_cell(value)
    append_cell do
      @io << '"'
      value.each_byte do |byte|
        case byte
        when '"'
          @io << %("")
        else
          @io.write_byte byte
        end
      end
      @io << '"'
    end
  end

  private def append_cell
    @io << "," unless @first_cell_in_row
    yield
    @first_cell_in_row = false
  end

  # A CSV Row being built.
  struct Row
    @builder : Builder

    # :nodoc:
    def initialize(@builder)
    end

    # Appends the given value to this row.
    def <<(value : String)
      if needs_quotes?(value)
        @builder.quote_cell value
      else
        @builder.cell { |io| io << value }
      end
    end

    # ditto
    def <<(value : Nil | Bool | Char | Number | Symbol)
      @builder.cell { |io| io << value }
    end

    # ditto
    def <<(value)
      self << value.to_s
    end

    # Appends the given values to this row.
    def concat(values : Enumerable)
      values.each do |value|
        self << value
      end
    end

    # ditto
    def concat(*values)
      concat values
    end

    # Appends a comma, thus skipping a cell.
    def skip_cell
      self << nil
    end

    private def needs_quotes?(value)
      value.each_byte do |byte|
        case byte.unsafe_chr
        when ',', '\n', '"'
          return true
        end
      end
      false
    end
  end
end
