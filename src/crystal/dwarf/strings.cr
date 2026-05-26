module Crystal
  module DWARF
    struct Strings
      def initialize(@buffer : Bytes)
      end

      def decode(index : Int)
        String.new(@buffer + index, truncate_at_null: true)
      end
    end
  end
end
