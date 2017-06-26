# A write-only `IO` object to compress data in the gzip format.
#
# Instances of this class wrap another `IO` object. When you write to this
# instance, it compresses the data and writes it to the underlying `IO`.
#
# NOTE: unless created with a block, `close` must be invoked after all
# data has been written to a `Gzip::Writer` instance.
#
# ### Example: compress a file
#
# ```
# require "gzip"
#
# File.write("file.txt", "abc")
#
# File.open("./file.txt", "r") do |input_file|
#   File.open("./file.gzip", "w") do |output_file|
#     Gzip::Writer.open(output_file) do |gzip|
#       IO.copy(input_file, gzip)
#     end
#   end
# end
# ```
class Gzip::Writer
  include IO

  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  # The header to write to the gzip stream. It will be
  # written just before the first write to this writer.
  # Changes to the header after the first write are
  # ignored.
  getter header = Header.new

  # Creates a new writer to the given *io*.
  def initialize(@io : IO, @level = Gzip::DEFAULT_COMPRESSION, @sync_close = false)
    @crc32 = CRC32.initial # CRC32 of written data
    @isize = 0             # Total size of written data
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : String, level = Gzip::DEFAULT_COMPRESSION)
    new(::File.new(filename, "w"), level: level, sync_close: true)
  end

  # Creates a new writer to the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, level = Gzip::DEFAULT_COMPRESSION, sync_close = false)
    writer = new(io, level: level, sync_close: sync_close)
    yield writer ensure writer.close
  end

  # Creates a new writer to the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String, level = Gzip::DEFAULT_COMPRESSION)
    writer = new(filename, level: level)
    yield writer ensure writer.close
  end

  # Always raises `IO::Error` because this is a write-only `IO`.
  def read(slice : Bytes)
    raise IO::Error.new("Can't read from Gzip::Writer")
  end

  # See `IO#write`.
  def write(slice : Bytes) : Nil
    check_open

    flate_io = write_header
    flate_io.write(slice)

    # Update CRC32 and total data size
    @crc32 = CRC32.update(slice, @crc32)
    @isize += slice.size
  end

  # Flushes data, forcing writing the gzip header if no
  # data has been written yet.
  #
  # See `IO#flush`.
  def flush
    check_open

    flate_io = write_header
    flate_io.flush
  end

  # Closes this writer. Must be invoked after all data has been written.
  def close
    return if @closed
    @closed = true

    flate_io = write_header
    flate_io.close

    @io.write_bytes @crc32, IO::ByteFormat::LittleEndian
    @io.write_bytes @isize, IO::ByteFormat::LittleEndian

    @io.close if @sync_close
  end

  private def write_header
    flate_io = @flate_io
    unless flate_io
      flate_io = @flate_io = Flate::Writer.new(@io, level: @level)
      header.to_io(@io)
    end
    flate_io
  end
end
