# A write-only `IO` object to compress data in the DEFLATE format.
#
# Instances of this class wrap another IO object. When you write to this
# instance, it compresses the data and writes it to the underlying IO.
#
# NOTE: unless created with a block, `close` must be invoked after all
# data has been written to a Flate::Writer instance.
class Flate::Writer < IO
  # If `#sync_close?` is `true`, closing this IO will close the underlying IO.
  property? sync_close : Bool

  # Creates an instance of Flate::Writer. `close` must be invoked after all data
  # has written.
  def initialize(@output : IO, level : Int32 = Flate::DEFAULT_COMPRESSION,
                 strategy : Flate::Strategy = Flate::Strategy::DEFAULT,
                 @sync_close : Bool = false, @dict : Bytes? = nil)
    unless -1 <= level <= 9
      raise ArgumentError.new("Invalid Flate level: #{level} (must be in -1..9)")
    end

    @buf = uninitialized UInt8[8192] # output buffer used by zlib
    @stream = LibZ::ZStream.new
    @stream.zalloc = LibZ::AllocFunc.new { |opaque, items, size| GC.malloc(items * size) }
    @stream.zfree = LibZ::FreeFunc.new { |opaque, address| GC.free(address) }
    @closed = false
    ret = LibZ.deflateInit2(pointerof(@stream), level, LibZ::Z_DEFLATED, -LibZ::MAX_BITS, LibZ::DEF_MEM_LEVEL,
      strategy.value, LibZ.zlibVersion, sizeof(LibZ::ZStream))
    if ret != LibZ::Error::OK
      raise Flate::Error.new(ret, @stream)
    end
  end

  # Creates a new writer for the given *io*, yields it to the given block,
  # and closes it at its end.
  def self.open(io : IO, level : Int32 = Flate::DEFAULT_COMPRESSION,
                strategy : Flate::Strategy = Flate::Strategy::DEFAULT,
                sync_close : Bool = false, dict : Bytes? = nil)
    writer = new(io, level: level, strategy: strategy, sync_close: sync_close, dict: dict)
    yield writer ensure writer.close
  end

  # Always raises `IO::Error` because this is a write-only `IO`.
  def read(slice : Bytes)
    raise "Can't read from Flate::Writer"
  end

  # See `IO#write`.
  def write(slice : Bytes)
    check_open

    @stream.avail_in = slice.size
    @stream.next_in = slice
    consume_output LibZ::Flush::NO_FLUSH
  end

  # See `IO#flush`.
  def flush
    return if @closed

    consume_output LibZ::Flush::SYNC_FLUSH
  end

  # Closes this writer. Must be invoked after all data has been written.
  def close
    return if @closed
    @closed = true

    @stream.avail_in = 0
    @stream.next_in = Pointer(UInt8).null
    consume_output LibZ::Flush::FINISH
    LibZ.deflateEnd(pointerof(@stream))

    @output.close if @sync_close
  end

  # Returns `true` if this IO is closed.
  def closed?
    @closed
  end

  # :nodoc:
  def inspect(io)
    to_s(io)
  end

  private def consume_output(flush)
    loop do
      @stream.next_out = @buf.to_unsafe
      @stream.avail_out = @buf.size.to_u32
      LibZ.deflate(pointerof(@stream), flush) # no bad return value
      @output.write(@buf.to_slice[0, @buf.size - @stream.avail_out])
      break if @stream.avail_out != 0
    end
  end
end
