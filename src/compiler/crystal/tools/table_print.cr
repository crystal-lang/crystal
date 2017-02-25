module Crystal
  class TablePrint
    COL_SEP     = '|'
    CELL_MARGIN = ' '

    struct Separator
    end

    class Column
      def initialize
        @max_size = 0
      end

      def width
        @max_size
      end

      def will_render(cell)
        @max_size = Math.max(@max_size, cell.text.size) if cell.colspan == 1
      end

      def render_cell(table, cell)
        if cell.colspan == 1
          available_width = width
        else
          available_width = table.columns.skip(cell.column_index).first(cell.colspan).sum(&.width) + 3 * (cell.colspan - 1)
        end

        case cell.align
        when :left
          "%-#{available_width}s" % cell.text
        when :right
          "%+#{available_width}s" % cell.text
        when :center
          left = " " * ((available_width - cell.text.size) / 2)
          right = " " * (available_width - cell.text.size - left.size)
          "#{left}#{cell.text}#{right}"
        end
      end
    end

    class Cell
      property text : String
      property align : Symbol
      property colspan : Int32
      property! column_index : Int32

      def initialize(@text, @align, @colspan)
      end
    end

    alias RowTypes = Array(Cell) | Separator

    property! last_string_row : Array(Cell)
    property columns : Array(Column)

    def initialize(@io : IO)
      @data = [] of RowTypes
      @columns = [] of Column
    end

    def build
      with self yield self
      render
    end

    def separator
      @data << Separator.new
    end

    def row
      @last_string_row = [] of Cell
      @data << last_string_row
      with self yield
    end

    def cell(text, align = :left, colspan = 1)
      cell = Cell.new(text, align, colspan)
      last_string_row << cell
      column_for_last_cell.will_render(cell)
    end

    def cell(align = :left, colspan = 1)
      cell(String::Builder.build { |io| yield io }, align, colspan)
    end

    protected def render
      @data.each_with_index do |data_row, i|
        @io << '\n' if i != 0
        if data_row.is_a?(Separator)
          @io << "-" * (@columns.sum(&.width) + 1 + 3 * @columns.size)
        elsif data_row.is_a?(Array(Cell))
          column_index = 0
          data_row.each_with_index do |cell, i|
            cell.column_index = column_index

            @io << COL_SEP if i == 0
            @io << CELL_MARGIN << @columns[column_index].render_cell(self, cell) << CELL_MARGIN << COL_SEP

            column_index += cell.colspan
          end
        end
      end
    end

    protected def column_for_last_cell
      col = @columns[last_string_row.size - 1]?
      unless col
        col = Column.new
        @columns << col
      end
      col
    end
  end
end
