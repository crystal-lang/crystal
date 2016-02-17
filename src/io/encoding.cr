module IO
  # Has the name and the invalid option
  struct EncodingOptions
    getter name
    getter invalid

    def initialize(@name : String, @invalid : Symbol?)
      EncodingOptions.check_invalid(invalid)
    end

    def self.check_invalid(invalid)
      if invalid && invalid != :skip
        raise ArgumentError.new "valid values for `invalid` option are `nil` and `:skip`, not #{invalid.inspect}"
      end
    end
  end

  # :nodoc:
  class Encoder
    def initialize(@encoding_options : EncodingOptions)
      @iconv = Iconv.new("UTF-8", encoding_options.name, encoding_options.invalid)
      @closed = false
    end

    def write(io, slice : Slice(UInt8))
      inbuf_ptr = slice.to_unsafe
      inbytesleft = LibC::SizeT.new(slice.size)
      outbuf = uninitialized UInt8[1024]
      while inbytesleft > 0
        outbuf_ptr = outbuf.to_unsafe
        outbytesleft = LibC::SizeT.new(outbuf.size)
        err = @iconv.convert(pointerof(inbuf_ptr), pointerof(inbytesleft), pointerof(outbuf_ptr), pointerof(outbytesleft))
        if err == -1
          @iconv.handle_invalid(pointerof(inbuf_ptr), pointerof(inbytesleft))
        end
        io.write(outbuf.to_slice[0, outbuf.size - outbytesleft])
      end
    end

    def close
      return if @closed
      @closed = true
      @iconv.close
    end

    def finalize
      close
    end
  end

  # :nodoc:
  class Decoder
    BUFFER_SIZE     = 4 * 1024
    OUT_BUFFER_SIZE = 4 * 1024

    property out_slice

    def initialize(@encoding_options : EncodingOptions)
      @iconv = Iconv.new(encoding_options.name, "UTF-8", encoding_options.invalid)
      @buffer = Slice.new((GC.malloc_atomic(BUFFER_SIZE) as UInt8*), BUFFER_SIZE)
      @in_buffer = @buffer.to_unsafe
      @in_buffer_left = LibC::SizeT.new(0)
      @out_buffer = Slice.new((GC.malloc_atomic(OUT_BUFFER_SIZE) as UInt8*), OUT_BUFFER_SIZE)
      @out_slice = Slice.new(Pointer(UInt8).null, 0)
      @last_errno = 0
      @closed = false
    end

    def read(io)
      return unless @out_slice.empty?

      if @in_buffer_left == 0
        @in_buffer = @buffer.to_unsafe
        @in_buffer_left = LibC::SizeT.new(io.read(@buffer))
      elsif @last_errno == Errno::EINVAL
        # EINVAL means "An incomplete multibyte sequence has been encountered in the input."

        # If we have just a few bytes remaining to fill, move the ones we have to the beginning
        # and read into the rest, so we avoid just decoding a small amount of bytes
        buffer_remaining = BUFFER_SIZE - @in_buffer_left - (@in_buffer - @buffer.to_unsafe)
        if buffer_remaining < 64
          @buffer.copy_from(@in_buffer, @in_buffer_left)
          @in_buffer = @buffer.to_unsafe
          buffer_remaining = BUFFER_SIZE - @in_buffer_left
        end
        @in_buffer_left += LibC::SizeT.new(io.read(Slice.new(@in_buffer + @in_buffer_left, buffer_remaining)))
      end

      # If we just have a few bytes to decode, read more, just in case these don't produce a character
      if @in_buffer_left < 16
        buffer_remaining = BUFFER_SIZE - @in_buffer_left - (@in_buffer - @buffer.to_unsafe)
        @buffer.copy_from(@in_buffer, @in_buffer_left)
        @in_buffer = @buffer.to_unsafe
        @in_buffer_left += LibC::SizeT.new(io.read(Slice.new(@in_buffer + @in_buffer_left, buffer_remaining)))
      end

      out_buffer = @out_buffer.to_unsafe
      out_buffer_left = LibC::SizeT.new(OUT_BUFFER_SIZE)
      old_in_buffer_left = @in_buffer_left
      result = @iconv.convert(pointerof(@in_buffer), pointerof(@in_buffer_left), pointerof(out_buffer), pointerof(out_buffer_left))
      @out_slice = @out_buffer[0, OUT_BUFFER_SIZE - out_buffer_left]
      if result == -1
        if Errno.value == Errno::EILSEQ
          @iconv.handle_invalid(pointerof(@in_buffer), pointerof(@in_buffer_left))
        end

        if old_in_buffer_left == @in_buffer_left
          raise ArgumentError.new "incomplete multibyte sequence"
        end
        @last_errno = Errno.value
      else
        @last_errno = 0
      end
    end

    def read_byte(io)
      read(io)
      if out_slice.empty?
        nil
      else
        byte = out_slice.to_unsafe.value
        advance 1
        byte
      end
    end

    def read_utf8(io, slice)
      count = 0
      until slice.empty?
        read(io)
        break if out_slice.empty?

        available = Math.min(out_slice.size, slice.size)
        out_slice[0, available].copy_to(slice.to_unsafe, available)
        advance(available)
        count += available
        slice += available
      end
      count
    end

    def gets(io, delimiter : UInt8, limit : Int)
      read(io)
      return nil if @out_slice.empty?

      index = @out_slice.index(delimiter)
      if index
        # If we find it past the limit, limit the result
        if index > limit
          index = limit
        else
          index += 1
        end

        string = String.new(@out_slice[0, index])
        advance(index)
        return string
      end

      # Check if there's limit bytes in the out slice
      if @out_slice.size >= limit
        string = String.new(@out_slice[0, limit])
        advance(limit)
        return string
      end

      # We need to read from the out_slice into a Srting until we find that byte,
      # or until we consumed limit bytes
      String.build do |str|
        loop do
          limit -= @out_slice.size
          write str

          read(io)

          break if @out_slice.empty?

          index = @out_slice.index(delimiter)
          if index
            if index > limit
              index = limit
            else
              index += 1
            end
            write str, index
            break
          else
            if limit < @out_slice.size
              write(str, limit)
              break
            end
          end
        end
      end
    end

    def write(io)
      io.write @out_slice
      @out_slice = Slice.new(Pointer(UInt8).null, 0)
    end

    def write(io, numbytes)
      io.write @out_slice[0, numbytes]
      @out_slice += numbytes
    end

    def advance(numbytes)
      @out_slice += numbytes
    end

    def close
      return if @closed
      @closed = true

      @iconv.close
    end

    def finalize
      close
    end
  end
end
