# The IO::Buffered mixin enhances the IO module with input/output buffering.
#
# The buffering behaviour can be turned on/off with the `#sync=` method.
#
# Additionally, several methods, like `#gets`, are implemented in a more
# efficient way.
module IO::Buffered
  include IO

  BUFFER_SIZE = 8192

  @in_buffer_rem = Slice(UInt8).new(Pointer(UInt8).null, 0)
  @out_count = 0
  @sync = false
  @flush_on_newline = false

  # Reads at most *slice.size* bytes from the wrapped IO into *slice*. Returns the number of bytes read.
  abstract def unbuffered_read(slice : Slice(UInt8))

  # Writes at most *slice.size* bytes from *slice* into the wrapped IO. Returns the number of bytes written.
  abstract def unbuffered_write(slice : Slice(UInt8))

  # Flushes the wrapped IO.
  abstract def unbuffered_flush

  # Closes the wrapped IO.
  abstract def unbuffered_close

  # Rewinds the wrapped IO.
  abstract def unbuffered_rewind

  # :nodoc:
  def gets(delimiter : Char, limit : Int)
    check_open

    if delimiter.ord >= 128 || @encoding
      return super
    end

    raise ArgumentError.new "negative limit" if limit < 0

    limit = Int32::MAX if limit < 0

    delimiter_byte = delimiter.ord.to_u8

    # We first check, after filling the buffer, if the delimiter
    # is already in the buffer. In that case it's much faster to create
    # a String from a slice of the buffer instead of appending to a
    # IO::Memory, which happens in the other case.
    fill_buffer if @in_buffer_rem.empty?
    if @in_buffer_rem.empty?
      return nil
    end

    index = @in_buffer_rem.index(delimiter_byte)
    if index
      # If we find it past the limit, limit the result
      if index >= limit
        index = limit
      else
        index += 1
      end

      string = String.new(@in_buffer_rem[0, index])
      @in_buffer_rem += index
      return string
    end

    # We didn't find the delimiter, so we append to an IO::Memory until we find it,
    # or we reach the limit
    String.build do |buffer|
      loop do
        available = Math.min(@in_buffer_rem.size, limit)
        buffer.write @in_buffer_rem[0, available]
        @in_buffer_rem += available
        limit -= available

        if limit == 0
          break
        end

        fill_buffer if @in_buffer_rem.empty?

        if @in_buffer_rem.empty?
          if buffer.bytesize == 0
            return nil
          else
            break
          end
        end

        index = @in_buffer_rem.index(delimiter_byte)
        if index
          if index >= limit
            index = limit
          else
            index += 1
          end
          buffer.write @in_buffer_rem[0, index]
          @in_buffer_rem += index
          break
        end
      end
    end
  end

  # :nodoc:
  def read_byte : UInt8?
    check_open

    fill_buffer if @in_buffer_rem.empty?
    if @in_buffer_rem.empty?
      nil
    else
      b = @in_buffer_rem[0]
      @in_buffer_rem += 1
      b
    end
  end

  private def read_char_with_bytesize
    return super if @encoding || @in_buffer_rem.size < 4

    first = @in_buffer_rem[0].to_u32
    if first < 0x80
      @in_buffer_rem += 1
      return first.unsafe_chr, 1
    end

    second = (@in_buffer_rem[1] & 0x3f).to_u32
    if first < 0xe0
      @in_buffer_rem += 2
      return ((first & 0x1f) << 6 | second).unsafe_chr, 2
    end

    third = (@in_buffer_rem[2] & 0x3f).to_u32
    if first < 0xf0
      @in_buffer_rem += 3
      return ((first & 0x0f) << 12 | (second << 6) | third).unsafe_chr, 3
    end

    fourth = (@in_buffer_rem[3] & 0x3f).to_u32
    if first < 0xf8
      @in_buffer_rem += 4
      return ((first & 0x07) << 18 | (second << 12) | (third << 6) | fourth).unsafe_chr, 4
    end

    raise InvalidByteSequenceError.new("Unexpected byte 0x#{first.to_s(16)} in UTF-8 byte sequence")
  end

  # Buffered implementation of `IO#read(slice)`.
  def read(slice : Slice(UInt8))
    check_open

    count = slice.size
    return 0 if count == 0

    if @in_buffer_rem.empty?
      # If we are asked to read more than half the buffer's size,
      # read directly into the slice, as it's not worth the extra
      # memory copy.
      if count >= BUFFER_SIZE / 2
        return unbuffered_read(slice[0, count]).to_i
      else
        fill_buffer
        return 0 if @in_buffer_rem.empty?
      end
    end

    to_read = Math.min(count, @in_buffer_rem.size)
    slice.copy_from(@in_buffer_rem.pointer(to_read), to_read)
    @in_buffer_rem += to_read
    to_read
  end

  # Buffered implementation of `IO#write(slice)`.
  def write(slice : Slice(UInt8))
    check_open

    count = slice.size

    if sync?
      return unbuffered_write(slice)
    end

    if flush_on_newline?
      index = slice[0, count.to_i32].rindex('\n'.ord.to_u8)
      if index
        flush
        index += 1
        unbuffered_write slice[0, index]
        slice += index
        count -= index
      end
    end

    if count >= BUFFER_SIZE
      flush
      return unbuffered_write slice[0, count]
    end

    if count > BUFFER_SIZE - @out_count
      flush
    end

    slice.copy_to(out_buffer + @out_count, count)
    @out_count += count
    nil
  end

  # :nodoc:
  def write_byte(byte : UInt8)
    check_open

    if sync?
      return super
    end

    if @out_count >= BUFFER_SIZE
      flush
    end
    out_buffer[@out_count] = byte
    @out_count += 1

    if flush_on_newline? && byte === '\n'
      flush
    end
  end

  # Turns on/off flushing the underlying IO when a newline is written.
  def flush_on_newline=(flush_on_newline)
    @flush_on_newline = !!flush_on_newline
  end

  # Determines if this IO flushes automatically when a newline is written.
  def flush_on_newline?
    @flush_on_newline
  end

  # Turns on/off IO buffering. When `sync` is set to `true`, no buffering
  # will be done (that is, writing to this IO is immediately synced to the
  # underlying IO).
  def sync=(sync)
    flush if sync && !@sync
    @sync = !!sync
  end

  # Determines if this IO does buffering. If `true`, no buffering is done.
  def sync?
    @sync
  end

  # Flushes any buffered data and the underlying IO. Returns `self`.
  def flush
    unbuffered_write(Slice.new(out_buffer, @out_count)) if @out_count > 0
    unbuffered_flush
    @out_count = 0
    self
  end

  # Flushes and closes the underlying IO.
  def close
    flush if @out_count > 0
    unbuffered_close
    nil
  end

  # Rewinds the underlying IO. Returns `self`.
  def rewind
    unbuffered_rewind
    @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
    self
  end

  private def fill_buffer
    in_buffer = in_buffer()
    size = unbuffered_read(Slice.new(in_buffer, BUFFER_SIZE)).to_i
    @in_buffer_rem = Slice.new(in_buffer, size)
  end

  private def in_buffer
    @in_buffer ||= GC.malloc_atomic(BUFFER_SIZE.to_u32).as(UInt8*)
  end

  private def out_buffer
    @out_buffer ||= GC.malloc_atomic(BUFFER_SIZE.to_u32).as(UInt8*)
  end
end
