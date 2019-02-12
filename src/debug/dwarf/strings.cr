module Debug
  module DWARF
    struct Strings
      def initialize(@io : IO::FileDescriptor, @offset : UInt32 | UInt64)
      end

      def decode(strp)
        @io.seek(@offset + strp) do
          @io.gets('\0', chomp: true).to_s
        end
      end
    end
  end
end
