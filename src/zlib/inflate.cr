module Zlib
  class Inflate
    include IO

    def initialize(@input : IO, wbits = LibZ::MAX_BITS)
      @buf :: UInt8[8192] # input buffer used by zlib
      @stream = LibZ::ZStream.new
      ret = LibZ.inflateInit2(pointerof(@stream), wbits, LibZ.zlibVersion, sizeof(LibZ::ZStream))
      check_error(ret)
    end

    private def check_error(err)
      msg = @stream.msg ? String.new(@stream.msg) : nil
      ZlibError.check_error(err, msg)
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to InflateIO"
    end

    def read(slice : Slice(UInt8))
      prepare_input_data

      @stream.avail_out = slice.size.to_u32
      @stream.next_out = slice.to_unsafe

      # if no data was read, and the stream is not finished keep inflating
      while perform_inflate != LibZ::STREAM_END && @stream.avail_out == slice.size.to_u32
        prepare_input_data
      end

      slice.size - @stream.avail_out
    end

    private def prepare_input_data
      return if @stream.avail_in > 0
      @stream.next_in = @buf.buffer
      @stream.avail_in = @input.read(@buf.to_slice).to_u32
    end

    private def perform_inflate
      flush = @stream.avail_in == 0 ? LibZ::Flush::FINISH : LibZ::Flush::NO_FLUSH
      ret = LibZ.inflate(pointerof(@stream), flush)
      check_error(ret)
      ret
    end
  end
end
