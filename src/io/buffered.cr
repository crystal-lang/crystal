# The `IO::Buffered` mixin enhances an `IO` with input/output buffering.
#
# The buffering behaviour can be turned on/off with the `#sync=` method.
#
# Additionally, several methods, like `#gets`, are implemented in a more
# efficient way.
module IO::Buffered
  BUFFER_SIZE = 8192

  @in_buffer_rem = Bytes.empty
  @out_count = 0
  @sync = false
  @flush_on_newline = false

  # Reads at most *slice.size* bytes from the wrapped `IO` into *slice*.
  # Returns the number of bytes read.
  abstract def unbuffered_read(slice : Bytes)

  # Writes at most *slice.size* bytes from *slice* into the wrapped `IO`.
  # Returns the number of bytes written.
  abstract def unbuffered_write(slice : Bytes)

  # Flushes the wrapped `IO`.
  abstract def unbuffered_flush

  # Closes the wrapped `IO`.
  abstract def unbuffered_close

  # Rewinds the wrapped `IO`.
  abstract def unbuffered_rewind

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

  # Buffered implementation of `IO#read(slice)`.
  def read(slice : Bytes)
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

  # Returns the bytes hold in the read buffer.
  #
  # This method only performs a read to return
  # peek data if the current buffer is empty:
  # otherwise no read is performed and whatever
  # is in the buffer is returned.
  def peek : Bytes?
    check_open

    if @in_buffer_rem.empty?
      fill_buffer
      if @in_buffer_rem.empty?
        return Bytes.empty # EOF
      end
    end

    @in_buffer_rem
  end

  # :nodoc:
  def skip(bytes_count) : Nil
    check_open

    if bytes_count <= @in_buffer_rem.size
      @in_buffer_rem += bytes_count
      return
    end

    bytes_count -= @in_buffer_rem.size
    @in_buffer_rem = Bytes.empty

    super(bytes_count)
  end

  # Buffered implementation of `IO#write(slice)`.
  def write(slice : Bytes)
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

  # Turns on/off flushing the underlying `IO` when a newline is written.
  def flush_on_newline=(flush_on_newline)
    @flush_on_newline = !!flush_on_newline
  end

  # Determines if this `IO` flushes automatically when a newline is written.
  def flush_on_newline?
    @flush_on_newline
  end

  # Turns on/off `IO` buffering. When *sync* is set to `true`, no buffering
  # will be done (that is, writing to this `IO` is immediately synced to the
  # underlying `IO`).
  def sync=(sync)
    flush if sync && !@sync
    @sync = !!sync
  end

  # Determines if this `IO` does buffering. If `true`, no buffering is done.
  def sync?
    @sync
  end

  # Flushes any buffered data and the underlying `IO`. Returns `self`.
  def flush
    unbuffered_write(Slice.new(out_buffer, @out_count)) if @out_count > 0
    unbuffered_flush
    @out_count = 0
    self
  end

  # Flushes and closes the underlying `IO`.
  def close : Nil
    flush if @out_count > 0
  ensure
    unbuffered_close
  end

  # Rewinds the underlying `IO`. Returns `self`.
  def rewind
    unbuffered_rewind
    @in_buffer_rem = Bytes.empty
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
