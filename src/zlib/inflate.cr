# A read-only `IO` object to decompress data in zlib or gzip format.
#
# Instances of this class wrap another IO object. When you read from this instance
# instance, it reads data from the underlying IO, decompresses it, and returns
# it to the caller.
#
# ### Example: decompress text a file
#
# ```
# string = File.open("./file.gzip", "r") do |file|
#   Zlib::Inflate.gzip(file) do |inflate|
#     inflate.gets_to_end
#   end
# end
# puts string
# ```
#
# See also: `Zlib::Deflate` for compressing data.
class Zlib::Inflate
  include IO

  # If `sync_close` is true, closing this IO will close the underlying IO.
  property? sync_close : Bool

  # Creates an instance of Zlib::Inflate.
  def initialize(@input : IO, wbits = LibZ::MAX_BITS, @sync_close : Bool = false)
    @buf = uninitialized UInt8[8192] # input buffer used by zlib
    @stream = LibZ::ZStream.new
    @stream.zalloc = LibZ::AllocFunc.new { |opaque, items, size| GC.malloc(items * size) }
    @stream.zfree = LibZ::FreeFunc.new { |opaque, address| GC.free(address) }
    ret = LibZ.inflateInit2(pointerof(@stream), wbits, LibZ.zlibVersion, sizeof(LibZ::ZStream))
    if ret != LibZ::Error::OK
      raise Zlib::Error.new(ret, @stream)
    end
    @closed = false
  end

  # Creates an instance of Zlib::Inflate, yields it to the given block, and closes
  # it at its end.
  def self.new(input : IO, wbits = LibZ::MAX_BITS, sync_close : Bool = false)
    inflate = new input, wbits: wbits, sync_close: sync_close
    begin
      yield inflate
    ensure
      inflate.close
    end
  end

  # Creates an instance of Zlib::Inflate for the gzip format.
  # has written.
  def self.gzip(input, sync_close : Bool = false) : self
    new input, wbits: GZIP, sync_close: sync_close
  end

  # Creates an instance of Zlib::Inflate for the gzip format, yields it to the given block, and closes
  # it at its end.
  def self.gzip(input, sync_close : Bool = false)
    inflate = gzip input, sync_close: sync_close
    begin
      yield inflate
    ensure
      inflate.close
    end
  end

  # Always raises: this is a read-only IO.
  def write(slice : Slice(UInt8))
    raise IO::Error.new "Can't write to InflateIO"
  end

  # See `IO#read`.
  def read(slice : Slice(UInt8))
    check_open

    return 0 if slice.empty?

    while true
      if @stream.avail_in == 0
        @stream.next_in = @buf.to_unsafe
        @stream.avail_in = @input.read(@buf.to_slice).to_u32
        return 0 if @stream.avail_in == 0
      end

      @stream.avail_out = slice.size.to_u32
      @stream.next_out = slice.to_unsafe

      ret = LibZ.inflate(pointerof(@stream), LibZ::Flush::NO_FLUSH)
      read_bytes = slice.size - @stream.avail_out
      case ret
      when LibZ::Error::NEED_DICT,
           LibZ::Error::DATA_ERROR,
           LibZ::Error::MEM_ERROR
        raise Zlib::Error.new(ret, @stream)
      when LibZ::Error::STREAM_END
        return read_bytes
      else
        # LibZ.inflate might not write any data to the output slice because
        # it might need more input. We can know this happened because `ret`
        # is not STREAM_END.
        if read_bytes == 0
          next
        else
          return read_bytes
        end
      end
    end
  end

  # Closes this IO.
  def close
    return if @closed
    @closed = true

    LibZ.inflateEnd(pointerof(@stream))

    @input.close if @sync_close
  end

  # Returns `true` if this IO is closed.
  def closed?
    @closed
  end

  # :nodoc:
  def inspect(io)
    to_s(io)
  end
end
