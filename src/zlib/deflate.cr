module Zlib
  class Deflate
    include IO

    def initialize(@output : IO, level = LibZ::DEFAULT_COMPRESSION, wbits = LibZ::MAX_BITS,
                   mem_level = LibZ::DEF_MEM_LEVEL, strategy = LibZ::Strategy::DEFAULT_STRATEGY)
      @buf = uninitialized UInt8[8192] # output buffer used by zlib
      @stream = LibZ::ZStream.new
      @stream.zalloc = LibZ::AllocFunc.new { |opaque, items, size| GC.malloc(items * size) }
      @stream.zfree = LibZ::FreeFunc.new { |opaque, address| GC.free(address) }
      @closed = false
      ret = LibZ.deflateInit2(pointerof(@stream), level, LibZ::Z_DEFLATED, wbits, mem_level,
        strategy, LibZ.zlibVersion, sizeof(LibZ::ZStream))
      check_error(ret)
    end

    def self.gzip(output)
      new output, wbits: GZIP
    end

    def read(slice : Slice(UInt8))
      raise "can't read from Zlib::Deflate"
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "closed stream" if closed?

      @stream.avail_in = slice.size
      @stream.next_in = slice
      consume_output LibZ::Flush::NO_FLUSH
    end

    def flush
      return if @closed

      consume_output LibZ::Flush::SYNC_FLUSH
    end

    def close
      return if @closed
      @closed = true

      @stream.avail_in = 0
      @stream.next_in = Pointer(UInt8).null
      consume_output LibZ::Flush::FINISH
      LibZ.deflateEnd(pointerof(@stream))
      @output.close
    end

    def closed?
      @closed
    end

    def inspect(io)
      to_s(io)
    end

    private def consume_output(flush)
      loop do
        @stream.next_out = @buf.to_unsafe
        @stream.avail_out = @buf.size.to_u32
        ret = LibZ.deflate(pointerof(@stream), flush)
        check_error(ret)
        @output.write(@buf.to_slice[0, @buf.size - @stream.avail_out])
        break if @stream.avail_out != 0
      end
    end

    private def check_error(err)
      msg = @stream.msg ? String.new(@stream.msg) : nil
      ZlibError.check_error(err, msg)
    end
  end
end
