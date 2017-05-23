# A read-only `IO` object to decompress data in the gzip format.
#
# Instances of this class wrap another IO object. When you read from this instance
# instance, it reads data from the underlying IO, decompresses it, and returns
# it to the caller.
#
# NOTE: A gzip stream can contain zero or more members. If it contains
# no members, `header` will be `nil`. If it contains one or more
# members, only the first header will be recorded here. This is
# because gzipping multiple members is not common as one usually
# combines gzip with tar. If, however, multiple members are present
# then reading from this reader will return the concatenation of
# all the members.
#
# ### Example: decompress a gzip file
#
# ```
# require "gzip"
#
# File.write("file.gzip", Bytes[31, 139, 8, 0, 0, 0, 0, 0, 0, 3, 75, 76, 74, 6, 0, 194, 65, 36, 53, 3, 0, 0, 0])
#
# string = File.open("file.gzip") do |file|
#   Gzip::Reader.open(file) do |gzip|
#     gzip.gets_to_end
#   end
# end
# string # => "abc"
# ```
class Gzip::Reader
  include IO

  # Whether to close the enclosed `IO` when closing this reader.
  property? sync_close = false

  # Returns `true` if this reader is closed.
  getter? closed = false

  # Returns the first header in the gzip stream, if any.
  getter header : Header?

  @flate_io : Flate::Reader?

  # Creates a new reader from the given *io*.
  def initialize(@io : IO, @sync_close = false)
    @crc32 = CRC32.initial # CRC32 of written data
    @isize = 0_u32         # Total size of written data

    first_byte = @io.read_byte

    # A gzip file could be empty (have no members), so
    # we account for that case
    return unless first_byte

    @header = Header.new(first_byte, @io)
    @flate_io = Flate::Reader.new(@io)
  end

  # Creates a new reader from the given *filename*.
  def self.new(filename : String)
    new(::File.new(filename), sync_close: true)
  end

  # Creates a new reader from the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, sync_close = false)
    reader = new(io, sync_close: sync_close)
    yield reader ensure reader.close
  end

  # Creates a new reader from the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String)
    reader = new(filename)
    yield reader ensure reader.close
  end

  # See `IO#read`.
  def read(slice : Bytes)
    check_open

    return 0 if slice.empty?

    while true
      flate_io = @flate_io
      return 0 unless flate_io

      read_bytes = flate_io.read(slice)
      if read_bytes == 0
        crc32 = @io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        isize = @io.read_bytes(UInt32, IO::ByteFormat::LittleEndian)

        if crc32 != @crc32
          raise Gzip::Error.new("CRC32 checksum mismatch")
        end

        if isize != @isize
          raise Gzip::Error.new("isize mismatch")
        end

        # Reset checksum and total size for next entry
        @crc32 = CRC32.initial
        @isize = 0_u32

        # Check if another header with data comes
        first_byte = @io.read_byte
        if first_byte
          Header.new(first_byte, @io)
          @flate_io = Flate::Reader.new(@io)
        else
          @flate_io = nil
          break
        end
      else
        # Update CRC32 and total data size
        @crc32 = CRC32.update(slice[0, read_bytes], @crc32)
        @isize += read_bytes

        break
      end
    end

    read_bytes
  end

  # Always raises `IO::Error` because this is a read-only `IO`.
  def write(slice : Bytes) : Nil
    raise IO::Error.new("Can't write to Gzip::Reader")
  end

  # Closes this reader.
  def close
    return if @closed
    @closed = true

    @flate_io.try &.close
    @io.close if @sync_close
  end
end
