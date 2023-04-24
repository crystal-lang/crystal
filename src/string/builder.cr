require "io"

# Similar to `IO::Memory`, but optimized for building a single string.
#
# You should never have to deal with this class. Instead, use `String.build`.
class String::Builder < IO
  getter bytesize : Int32
  getter capacity : Int32
  @buffer : Pointer(UInt8)

  def initialize(capacity : Int = 64)
    String.check_capacity_in_bounds(capacity)

    # Make sure to also be able to hold
    # the header size plus the trailing zero byte
    capacity += String::HEADER_SIZE + 1

    @buffer = GC.malloc_atomic(capacity.to_u32).as(UInt8*)
    @bytesize = 0
    @capacity = capacity.to_i
    @finished = false
  end

  def self.build(capacity : Int = 64, &) : String
    builder = new(capacity)
    yield builder
    builder.to_s
  end

  def self.new(string : String)
    io = new(string.bytesize)
    io << string
    io
  end

  def read(slice : Bytes) : NoReturn
    raise "Not implemented"
  end

  def write(slice : Bytes) : Nil
    return if slice.empty?

    count = slice.size
    new_bytesize = real_bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + real_bytesize, count)
    @bytesize += count
  end

  def write_byte(byte : UInt8) : Nil
    new_bytesize = real_bytesize + 1
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    @buffer[real_bytesize] = byte

    @bytesize += 1

    nil
  end

  def write_string(slice : Bytes) : Nil
    write(slice)
  end

  def set_encoding(encoding : String, invalid : Symbol? = nil) : Nil
    unless utf8_encoding?(encoding, invalid)
      raise "Can't change encoding of String::Builder"
    end
  end

  def buffer : Pointer(UInt8)
    @buffer + String::HEADER_SIZE
  end

  def empty? : Bool
    @bytesize == 0
  end

  # Chomps the last byte from the string buffer.
  # If the byte is `'\n'` and there's a `'\r'` before it, it is also removed.
  def chomp!(byte : UInt8) : self
    if bytesize > 0 && buffer[bytesize - 1] == byte
      back(1)

      if byte === '\n' && bytesize > 0 && buffer[bytesize - 1] === '\r'
        back(1)
      end
    end
    self
  end

  # Moves the write pointer, and the resulting string bytesize,
  # by the given *amount*.
  def back(amount : Int) : Int32
    unless 0 <= amount <= @bytesize
      raise ArgumentError.new "Invalid back amount"
    end

    @bytesize -= amount
  end

  def to_s : String
    raise "Can only invoke 'to_s' once on String::Builder" if @finished
    @finished = true

    write_byte 0_u8

    # Try to reclaim some memory if capacity is bigger than what we need
    real_bytesize = real_bytesize()
    if @capacity > real_bytesize
      resize_to_capacity(real_bytesize)
    end

    String.set_crystal_type_id(@buffer)
    str = @buffer.as(String)
    str.initialize_header((bytesize - 1).to_i)
    str
  end

  private def real_bytesize
    @bytesize + String::HEADER_SIZE
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = GC.realloc(@buffer, @capacity)
  end
end
