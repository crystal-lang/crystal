# Simpler alternative to IO::Memory, dedicated to parse DWARF sections:
#
# - always read-only
# - returns slices to the internal buffer (no allocations)
# - reads (un)signed LEB128 integers
# - reads unsigned 24-bit integers
#
# WARNING: Assumes the program file to be the current system's endianness.
struct Crystal::DWARF::Reader
  def self.new(bytes : Bytes)
    new(bytes.to_unsafe, bytes.size)
  end

  getter pointer : UInt8*
  getter bytesize : Int32

  def initialize(@pointer, @bytesize)
    @pos = 0
  end

  def pos : Int32
    @pos
  end

  def current : UInt8*
    @pointer + @pos
  end

  def remainder : Int32
    @bytesize - @pos
  end

  def read_ulong(bytesize : Int) : UInt32 | UInt64
    case bytesize
    when 8
      read_u64
    when 4
      read_u32
    else
      raise Error.new("Invalid bytesize #{bytesize}")
    end
  end

  def read_u8 : UInt8
    buf = uninitialized UInt8[1]
    read(buf.to_slice)
    buf.to_unsafe.value
  end

  def read_i8 : Int8
    buf = uninitialized UInt8[1]
    read(buf.to_slice)
    buf.to_unsafe.as(Int8*).value
  end

  def read_u16 : UInt16
    buf = uninitialized UInt8[2]
    read(buf.to_slice)
    buf.to_unsafe.as(UInt16*).value
  end

  def read_u24 : UInt32
    buf = uninitialized UInt8[4]

    {% if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian %}
      read(buf.to_slice[0, 3])
      buf.to_unsafe[3] = 0_u8
    {% else %}
      buf.to_unsafe[0] = 0_u8
      read(buf.to_slice[1, 3])
    {% end %}

    buf.to_unsafe.as(UInt32*).value
  end

  def read_u32 : UInt32
    buf = uninitialized UInt8[4]
    read(buf.to_slice)
    buf.to_unsafe.as(UInt32*).value
  end

  def read_u64 : UInt64
    buf = uninitialized UInt8[8]
    read(buf.to_slice)
    buf.to_unsafe.as(UInt64*).value
  end

  def read_u128 : UInt128
    buf = uninitialized UInt8[16]
    read(buf.to_slice)
    read(16).to_unsafe.as(UInt128*).value
  end

  def read_unsigned(bytes : Bytes, type : F.class) : UInt64 forall F
    value = F.zero
    buf = Bytes.new(pointerof(value).as(UInt8*), sizeof(F))

    {% if IO::ByteFormat::SystemEndian == IO::ByteFormat::BigEndian %}
      buf += sizeof(F) - bytes.size
    {% end %}

    bytes.copy_to(buf, bytes.size)
    value
  end

  def read_uleb128 : UInt32
    result = 0_u32
    shift = 0

    while true
      byte = read_u8
      result |= (byte & 0x7f_u8).to_u32 << shift
      break if byte.bit(7) == 0
      shift += 7
    end

    result
  end

  def read_sleb128 : Int32
    result = 0_i32
    shift = 0
    size = 32
    byte = 0_u8

    while true
      byte = read_u8
      result |= (byte & 0x7f_u8).to_i32 << shift
      shift += 7
      break if byte.bit(7) == 0
    end

    # sign bit of byte is 2nd high order bit (0x40)
    if (shift < size) && (byte.bit(6) == 1)
      result |= -(1 << shift) # sign extend
    end

    result
  end

  def read(slice : Bytes) : Nil
    bytes_count = slice.size
    pos = @pos

    if bytes_count <= remainder
      (@pointer + pos).copy_to(slice.to_unsafe, bytes_count)
      @pos = pos + bytes_count
    else
      raise IO::EOFError.new
    end
  end

  def read(bytes_count : Int) : Bytes
    bytes_count = bytes_count.to_i32
    pos = @pos

    if bytes_count <= remainder
      @pos = pos + bytes_count
      Bytes.new(@pointer + pos, bytes_count, read_only: true)
    else
      raise IO::EOFError.new
    end
  end

  def read_string : Bytes
    start = @pointer + @pos
    size = Bytes.new(start, remainder).index!(0_u8)
    skip(size + 1) # chomp trailing NULL byte
    Bytes.new(start, size)
  end

  def skip_string : Nil
    size = Bytes.new(@pointer + @pos, remainder).index!(0_u8)
    skip(size + 1) # chomp trailing NULL byte
  end

  def skip(bytes_count : Int) : Nil
    bytes_count = bytes_count.to_i32

    if bytes_count <= remainder
      @pos += bytes_count
    else
      raise IO::EOFError.new
    end
  end

  def rewind : Nil
    @pos = 0
  end

  def empty? : Bool
    @bytesize == 0
  end

  def eof? : Bool
    @pos == @bytesize
  end
end
