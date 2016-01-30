module Zlib
  class Inflate
    include IO

    def initialize(@input : IO, wbits = LibZ::MAX_BITS)
      @buf = uninitialized UInt8[8192] # input buffer used by zlib
      @stream = LibZ::ZStream.new
      @stream.zalloc = LibZ::AllocFunc.new { |opaque, items, size| GC.malloc(items * size) }
      @stream.zfree = LibZ::FreeFunc.new { |opaque, address| GC.free(address) }
      ret = LibZ.inflateInit2(pointerof(@stream), wbits, LibZ.zlibVersion, sizeof(LibZ::ZStream))
      if ret != LibZ::Error::OK
        raise Zlib::Error.new(ret, @stream)
      end
    end

    def self.gzip(input)
      new input, wbits: GZIP
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to InflateIO"
    end

    def read(slice : Slice(UInt8))
      raise IO::Error.new "closed stream" if closed?

      if @stream.avail_in == 0
        @stream.next_in = @buf.to_unsafe
        @stream.avail_in = @input.read(@buf.to_slice).to_u32
      end

      @stream.avail_out = slice.size.to_u32
      @stream.next_out = slice.to_unsafe

      ret = LibZ.inflate(pointerof(@stream), LibZ::Flush::NO_FLUSH)
      case ret
      when LibZ::Error::NEED_DICT
      when LibZ::Error::DATA_ERROR
      when LibZ::Error::MEM_ERROR
        raise Zlib::Error.new(ret, @stream)
      end

      slice.size - @stream.avail_out
    end

    def close
      return if @closed
      @closed = true

      LibZ.inflateEnd(pointerof(@stream))
      @input.close
    end

    def closed?
      @closed
    end

    def inspect(io)
      to_s(io)
    end
  end
end
