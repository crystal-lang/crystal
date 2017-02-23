# A header in a gzip stream.
class Gzip::Header
  property modification_time : Time
  property os : UInt8
  property extra = Bytes.empty
  property name : String?
  property comment : String?

  # :nodoc:
  @[Flags]
  enum Flg : UInt8
    TEXT
    HCRC
    EXTRA
    NAME
    COMMENT
  end

  # :nodoc:
  def initialize
    @modification_time = Time.new
    @os = 255_u8 # Unknown
  end

  # :nodoc:
  def initialize(first_byte : UInt8, io : IO)
    header = uninitialized UInt8[10]
    header[0] = first_byte
    io.read_fully(header.to_slice + 1)

    if header[0] != ID1 || header[1] != ID2 || header[2] != DEFLATE
      raise Error.new("Invalid gzip header")
    end

    flg = Flg.new(header[3])

    seconds = IO::ByteFormat::LittleEndian.decode(Int32, header.to_slice[4, 4])
    @modification_time = Time.epoch(seconds).to_local

    xfl = header[8]
    @os = header[9]

    if flg.extra?
      xlen = io.read_byte.not_nil!
      @extra = Bytes.new(xlen)
      io.read_fully(@extra)
    end

    if flg.name?
      @name = io.gets('\0', chomp: true)
    end

    if flg.comment?
      @comment = io.gets('\0', chomp: true)
    end

    if flg.hcrc?
      crc16 = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      # TODO check crc16
    end
  end

  # :nodoc:
  def to_io(io)
    # header
    io.write_byte ID1
    io.write_byte ID2

    # compression method
    io.write_byte DEFLATE

    # flg
    flg = Flg::None
    flg |= Flg::EXTRA unless @extra.empty?
    flg |= Flg::NAME if @name
    flg |= Flg::COMMENT if @comment
    io.write_byte flg.value

    # time
    io.write_bytes(modification_time.epoch.to_u32, IO::ByteFormat::LittleEndian)

    # xfl
    io.write_byte 0_u8

    # os
    io.write_byte os

    unless @extra.empty?
      io.write_byte @extra.size.to_u8
      io.write(@extra)
    end

    if name = @name
      io << name
      io.write_byte 0_u8
    end

    if comment = @comment
      io << comment
      io.write_byte 0_u8
    end
  end
end
