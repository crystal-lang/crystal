# A write-only `IO` object to compress data in the zlib format.
#
# Instances of this class wrap another IO object. When you write to this
# instance, it compresses the data and writes it to the underlying IO.
#
# NOTE: unless created with a block, `close` must be invoked after all
# data has been written to a Zlib::Writer instance.
class Zlib::Writer < IO
  # Whether to close the enclosed `IO` when closing this writer.
  property? sync_close = false

  # Returns `true` if this writer is closed.
  getter? closed = false

  # Creates a new writer to the given *io*.
  def initialize(@io : IO, @level = Zlib::DEFAULT_COMPRESSION, @sync_close = false, @dict : Bytes? = nil)
    @wrote_header = false
    @adler32 = Adler32.initial
    @flate_io = Flate::Writer.new(@io, level: level, dict: @dict)
  end

  # Creates a new writer to the given *filename*.
  def self.new(filename : String, level = Zlib::DEFAULT_COMPRESSION, dict : Bytes? = nil)
    new(::File.new(filename, "w"), level: level, sync_close: true, dict: dict)
  end

  # Creates a new writer to the given *io*, yields it to the given block,
  # and closes it at the end.
  def self.open(io : IO, level = Zlib::DEFAULT_COMPRESSION, sync_close = false, dict : Bytes? = nil)
    writer = new(io, level: level, sync_close: sync_close, dict: dict)
    yield writer ensure writer.close
  end

  # Creates a new writer to the given *filename*, yields it to the given block,
  # and closes it at the end.
  def self.open(filename : String, level = Zlib::DEFAULT_COMPRESSION, dict : Bytes? = nil)
    writer = new(filename, level: level, dict: dict)
    yield writer ensure writer.close
  end

  # Always raises `IO::Error` because this is a write-only `IO`.
  def read(slice : Bytes)
    raise IO::Error.new("Can't read from Gzip::Writer")
  end

  # See `IO#write`.
  def write(slice : Bytes) : Nil
    check_open

    write_header unless @wrote_header

    @flate_io.write(slice)
    @adler32 = Adler32.update(slice, @adler32)
  end

  # Flushes data, forcing writing the zlib header if no
  # data has been written yet.
  #
  # See `IO#flush`.
  def flush
    check_open

    write_header unless @wrote_header
    @flate_io.flush
  end

  # Closes this writer. Must be invoked after all data has been written.
  def close
    return if @closed
    @closed = true

    write_header unless @wrote_header

    @flate_io.close

    @io.write_bytes(@adler32, IO::ByteFormat::BigEndian)

    @io.close if @sync_close
  end

  private def write_header
    @wrote_header = true

    # CMF byte: 7 for window size, 8 for compression method (deflate)
    cmf = 0x78_u8
    @io.write_byte cmf

    dict = @dict

    flg = 0_u8

    if dict
      flg |= 1 << 5
    end

    case @level
    when 0..1
      flg |= 0 << 6
    when 2..5
      flg |= 1 << 6
    when 6, -1
      flg |= 2 << 6
    else
      flg |= 3 << 6
    end

    # CMF and FLG, when viewed as a 16-bit unsigned integer stored
    # in MSB order (CMF*256 + FLG), must be a multiple of 31
    flg += 31 - (cmf.to_u16*256 + flg.to_u16).remainder(31)

    @io.write_byte flg

    if dict
      dict_checksum = Adler32.checksum(dict)
      @io.write_bytes(dict_checksum, IO::ByteFormat::BigEndian)
    end
  end
end
