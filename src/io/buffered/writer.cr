# The BufferedIO mixin enhances the IO module with output buffering.
#
# The buffering behaviour can be turned on/off with the `#sync=` method.
module IO::Buffered::Writer
  BUFFER_SIZE = IO::Buffered::Common::BUFFER_SIZE

  # Due to https://github.com/manastech/crystal/issues/456 this
  # initialization logic must be copied in the included type's
  # initialize method:
  #
  # def initialize
  #   @out_count = 0
  #   @sync = false
  #   @flush_on_newline = false
  # end

  # Writes at most *slice.size* bytes from *slice* into the wrapped IO. Returns the number of bytes written.
  abstract def unbuffered_write(slice : Slice(UInt8))

  # Flushes the wrapped IO.
  abstract def unbuffered_flush

  # Buffered implementation of `IO#write(slice)`.
  def write(slice : Slice(UInt8))
    count = slice.size

    if sync?
      return unbuffered_write(slice).to_i
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
      unbuffered_write slice[0, count]
      return
    end

    if count > BUFFER_SIZE - @out_count
      flush
    end

    slice.copy_to(out_buffer + @out_count, count)
    @out_count += count
  end

  # :nodoc:
  def write_byte(byte : UInt8)
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
    # TODO: maybe instead of `sync=` we should rename this to `buffer=`,
    # because otherwise you have to think in a reversed way.
    flush if sync && !@sync
    @sync = !!sync
  end

  # Determines if this IO does buffering. If `true`, no buffering is done.
  def sync?
    @sync
  end

  # Flushes any buffered data and the underlying IO.
  def flush
    unbuffered_write(Slice.new(out_buffer, @out_count)) if @out_count > 0
    unbuffered_flush
    @out_count = 0
  end

  private def out_buffer
    @out_buffer ||= GC.malloc_atomic(BUFFER_SIZE.to_u32) as UInt8*
  end
end
