module Crystal
  module DWARF
    struct Strings
      def initialize(@io : IO::FileDescriptor, @offset : UInt32 | UInt64, size)
        # Read a good chunk of bytes to decode strings faster
        # (avoid seeking/reading the IO too many times)
        @buffer = Bytes.new(Math.max(16384, size))
        pos = @io.pos
        @io.read_fully(@buffer)
        @io.pos = pos
      end

      def decode(strp)
        # See if we can read it from the buffer
        if strp < @buffer.size
          index = @buffer.index('\0'.ord, offset: strp)
          return String.new(@buffer[strp, index - strp]) if index
        end

        # If not, try directly from the IO
        @io.seek(@offset + strp) do
          @io.gets('\0', chomp: true).to_s
        end
      end
    end
  end
end
