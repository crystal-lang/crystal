struct Slice(T)
  include Enumerable(T)
  include Iterable

  getter length

  def initialize(@pointer : Pointer(T), @length : Int32)
  end

  def self.new(length : Int32)
    pointer = Pointer(T).malloc(length)
    new(pointer, length)
  end

  def self.new(length : Int32)
    pointer = Pointer.malloc(length) { |i| yield i }
    new(pointer, length)
  end

  def self.new(length : Int32, value : T)
    new(length) { value }
  end

  def +(offset : Int)
    unless 0 <= offset <= length
      raise IndexError.new
    end

    Slice.new(@pointer + offset, @length - offset)
  end

  def [](index : Int)
    at(index)
  end

  def []=(index : Int, value : T)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexError.new
    end

    @pointer[index] = value
  end

  def [](start, count)
    unless 0 <= start <= @length
      raise IndexError.new
    end

    unless 0 <= count <= @length - start
      raise IndexError.new
    end

    Slice.new(@pointer + start, count)
  end

  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  def at(index : Int)
    index += length if index < 0
    if 0 <= index < length
      @pointer[index]
    else
      yield
    end
  end

  def empty?
    @length == 0
  end

  def each
    length.times do |i|
      yield @pointer[i]
    end
  end

  def each
    ItemIterator(T).new(self)
  end

  def pointer(length)
    unless 0 <= length <= @length
      raise IndexError.new
    end

    @pointer
  end

  def copy_from(source : Pointer(T), count)
    pointer(count).copy_from(source, count)
  end

  def copy_to(target : Pointer(T), count)
    pointer(count).copy_to(target, count)
  end

  def inspect(io)
    to_s(io)
  end

  def hexstring
    self as Slice(UInt8)

    str_length = length * 2
    String.new(str_length) do |buffer|
      hexstring(buffer)
      {str_length, str_length}
    end
  end

  def hexstring(buffer)
    self as Slice(UInt8)

    offset = 0
    each do |v|
      buffer[offset] = to_hex(v >> 4)
      buffer[offset + 1] = to_hex(v & 0x0f)
      offset += 2
    end

    nil
  end

  def rindex(value)
    rindex { |elem| elem == value }
  end

  def rindex
    (length - 1).downto(0) do |i|
      if yield @pointer[i]
        return i
      end
    end
    nil
  end

  private def to_hex(c)
    ((c < 10 ? 48_u8 : 87_u8) + c)
  end

  def to_slice
    self
  end

  def to_s(io)
    io << "["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def to_a
    Array(T).build(@length) do |pointer|
      pointer.copy_from(@pointer, @length)
      @length
    end
  end

  def to_unsafe
    @pointer
  end

  # :nodoc:
  class ItemIterator(T)
    include Iterator(T)

    def initialize(@slice : ::Slice(T), @index = 0)
    end

    def next
      value = @slice.at(@index) { stop }
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end
end
