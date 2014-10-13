class CSV
  def self.build
    io = StringIO.new
    build(io) { |builder| yield builder }
    io.to_s
  end

  def self.build(io : IO)
    builder = Builder.new(io)
    yield builder
  end

  class Builder
    def initialize(@io)
      @first_cell_in_row = true
    end

    def row
      yield Row.new(self)
      @io << "\n"
      @first_cell_in_row = true
    end

    def row(values : Enumerable)
      row do |row|
        values.each do |value|
          row << value
        end
      end
    end

    def row(*values)
      row values
    end

    def cell
      @io << "," unless @first_cell_in_row
      yield @io
      @first_cell_in_row = false
    end

    def quote_cell(value)
      @io << '"'
      value.each_byte do |byte|
        case byte
        when '"'.ord
          @io << %("")
        else
          @io.write_byte byte
        end
      end
      @io << '"'
    end

    struct Row
      def initialize(@builder)
      end

      def <<(value : String)
        if needs_quotes?(value)
          @builder.quote_cell value
        else
          @builder.cell { |io| io << value }
        end
      end

      def <<(value : Nil | Bool | Char | Number | Symbol)
        @builder.cell { |io| io << value }
      end

      def <<(value)
        self << value.to_s
      end

      def append(values : Enumerable)
        values.each do |value|
          self << value
        end
      end

      def append(*values)
        append values
      end

      def skip_cell
        self << nil
      end

      private def needs_quotes?(value)
        value.each_byte do |byte|
          case byte.chr
          when ',', '\n', '"'
            return true
          end
        end
        false
      end
    end
  end
end
