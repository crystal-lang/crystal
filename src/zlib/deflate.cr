module Zlib
  class Deflate
    include IO

    def initialize(@input : IO, level = LibZ::DEFAULT_COMPRESSION, wbits = LibZ::MAX_BITS,
                   mem_level = LibZ::DEF_MEM_LEVEL, strategy = LibZ::Strategy::DEFAULT_STRATEGY)
      @buf :: UInt8[8192]        # output buffer used by zlib
      @buf_read_from :: UInt32   # @buf_read_from/@buf_read_amount represents
      @buf_read_amount :: UInt32 #   the slice of the buffer available for the consumer of the IO
      @input_buf :: UInt8[8192]  # input buffer used by zlib
      @flush :: LibZ::Flush
      @stream = LibZ::ZStream.new
      ret = LibZ.deflateInit2(pointerof(@stream), level, LibZ::Z_DEFLATED, wbits, mem_level,
        strategy, LibZ.zlibVersion, sizeof(LibZ::ZStream))

      check_error(ret)
      reset_state
    end

    def read(slice : Slice(UInt8))
      # if there is output data not consumed, consume it and return.
      if @buf_read_amount > 0
        return read_and_consume_buffer(slice)
      end

      # the output buffer is free to be reused
      reset_state

      consume_from_input_and_prepare_output

      # countinue reading from IO until some output is generated in order to avoid read with zero bytes as result
      if @flush == LibZ::Flush::NO_FLUSH
        while @buf_read_amount == 0
          consume_from_input_and_prepare_output
        end
      end

      if @buf_read_amount > 0
        return read_and_consume_buffer(slice)
      else
        return 0
      end
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to DeflateIO"
    end

    private def check_error(err)
      msg = @stream.msg ? String.new(@stream.msg) : nil
      ZlibError.check_error(err, msg)
    end

    private def reset_state
      @stream.next_out = @buf.buffer
      @stream.avail_out = @buf.size.to_u32

      @buf_read_from = 0u32
      @buf_read_amount = 0u32
    end

    private def read_and_consume_buffer(slice)
      to_read = Math.min(slice.size.to_u32, @buf_read_amount)
      slice.copy_from((@buf.to_slice + @buf_read_from).to_unsafe, to_read)
      @buf_read_from += to_read
      @buf_read_amount -= to_read
      to_read.to_i32
    end

    private def consume_from_input_and_prepare_output
      # if all generated output by zlib was consumed, read from io and deflate
      if @stream.avail_in == 0
        read = @input.read(@input_buf.to_slice)
        @stream.next_in = @input_buf.buffer
        @stream.avail_in = read.to_u32
      end

      # if input io is at the very end, perform a FINISH
      @flush = @stream.avail_in == 0 && read == 0 ? LibZ::Flush::FINISH : LibZ::Flush::NO_FLUSH
      ret = LibZ.deflate(pointerof(@stream), @flush)
      check_error(ret)

      # output buffer is assumed free to be reused (there was a reset_state call)
      @buf_read_amount = (@buf.size - @stream.avail_out).to_u32
    end
  end
end
