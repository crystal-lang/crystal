module Crystal
  module DWARF
    struct Strings
      def initialize(@buffer : Bytes)
      end

      def decode(index : Int)
        if offset = @buffer.index(0, offset: index)
          size = offset - index
          String.new(@buffer.to_unsafe + index, size)
        end
      end
    end
  end
end
