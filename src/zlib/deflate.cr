# A write-only `IO` object to compress data in zlib or gzip format.
#
# Instances of this class wrap another IO object. When you write to this
# instance, it compresses the data and writes it to the underlying IO.
#
# **Note**: unless created with a block, `close` must be invoked after all
# data has been written to a Zlib::Deflate instance.
#
# ### Example: compress a file
#
# ```
# require "zlib"
#
# File.write("file.txt", "abc")
#
# File.open("./file.txt", "r") do |input_file|
#   File.open("./file.gzip", "w") do |output_file|
#     Zlib::Deflate.gzip(output_file) do |deflate|
#       IO.copy(input_file, deflate)
#     end
#   end
# end
# ```
#
# See also: `Zlib::Inflate` for decompressing data.
class Zlib::Deflate
  include IO

  # If `sync_close` is true, closing this IO will close the underlying IO.
  property? sync_close : Bool

  # Creates an instance of Zlib::Deflate. `close` must be invoked after all data
  # has written.
  def initialize(@output : IO, level = LibZ::DEFAULT_COMPRESSION, wbits = LibZ::MAX_BITS,
                 mem_level = LibZ::DEF_MEM_LEVEL, strategy = LibZ::Strategy::DEFAULT_STRATEGY,
                 @sync_close : Bool = false)
    @buf = uninitialized UInt8[8192] # output buffer used by zlib
    @stream = LibZ::ZStream.new
    @stream.zalloc = LibZ::AllocFunc.new { |opaque, items, size| GC.malloc(items * size) }
    @stream.zfree = LibZ::FreeFunc.new { |opaque, address| GC.free(address) }
    @closed = false
    ret = LibZ.deflateInit2(pointerof(@stream), level, LibZ::Z_DEFLATED, wbits, mem_level,
      strategy, LibZ.zlibVersion, sizeof(LibZ::ZStream))
    if ret != LibZ::Error::OK
      raise Zlib::Error.new(ret, @stream)
    end
  end

  # Creates an instance of Zlib::Deflate, yields it to the given block, and closes
  # it at its end.
  def self.new(output : IO, level = LibZ::DEFAULT_COMPRESSION, wbits = LibZ::MAX_BITS,
               mem_level = LibZ::DEF_MEM_LEVEL, strategy = LibZ::Strategy::DEFAULT_STRATEGY,
               sync_close : Bool = false)
    deflate = new(output, level: level, wbits: wbits, mem_level: mem_level, strategy: strategy, sync_close: sync_close)
    begin
      yield deflate
    ensure
      deflate.close
    end
  end

  # Creates an instance of Zlib::Deflate for the gzip format. `close` must be invoked after all data
  # has written.
  def self.gzip(output, sync_close : Bool = false) : self
    new output, wbits: GZIP, sync_close: sync_close
  end

  # Creates an instance of Zlib::Deflate for the gzip format, yields it to the given block, and closes
  # it at its end.
  def self.gzip(output, sync_close : Bool = false)
    deflate = gzip(output, sync_close: sync_close)
    begin
      yield deflate
    ensure
      deflate.close
    end
  end

  # Always raises: this is a write-only IO.
  def read(slice : Bytes)
    raise "can't read from Zlib::Deflate"
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

  # Closes this IO. Must be invoked after all data has been written.
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
