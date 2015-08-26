# A Slice is a `Pointer` with an associated length.
#
# While a pointer is unsafe because no bound checks are performend when reading from and writing to it,
# reading from and writing to a slice involve bound checks.
# In this way, a slice is a safe alternative to Pointer.
struct Slice(T)
  include Enumerable(T)
  include Iterable

  # Returns the length of this slice.
  #
  # ```
  # Slice(UInt8).new(3).length #=> 3
  # ```
  getter length

  # Creates a slice to the given *pointer*, bounded by the given *length*. This
  # method does not allocate heap memory.
  #
  # ```
  # ptr = Pointer.malloc(9) { |i| ('a'.ord + i).to_u8 }
  #
  # slice = Slice.new(ptr, 3)
  # slice.length      #=> 3
  # slice             #=> [97, 98, 99]
  #
  # String.new(slice) #=> "abc"
  # ```
  def initialize(@pointer : Pointer(T), @length : Int32)
  end

  # Allocates `length * sizeof(T)` bytes of heap memory initialized to zero
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice(UInt8).new(3)
  # slice #=> [0, 0, 0]
  # ```
  def self.new(length : Int32)
    pointer = Pointer(T).malloc(length)
    new(pointer, length)
  end

  # Allocates `length * sizeof(T)` bytes of heap memory initialized to the value
  # returned by the block (which is invoked once with each index in the range `0...length`)
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice.new(3) { |i| i + 10 }
  # slice #=> [10, 11, 12]
  # ```
  def self.new(length : Int32)
    pointer = Pointer.malloc(length) { |i| yield i }
    new(pointer, length)
  end

  # Allocates `length * sizeof(T)` bytes of heap memory initialized to *value*
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice.new(3, 10)
  # slice #=> [10, 10, 10]
  # ```
  def self.new(length : Int32, value : T)
    new(length) { value }
  end

  # Returns a new slice that i *offset* elements apart from this slice.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice #=> [10, 11, 12, 13, 14]
  #
  # slice2 = slice + 2
  # slice2 #=> [12, 13, 14]
  # ```
  def +(offset : Int)
    unless 0 <= offset <= length
      raise IndexError.new
    end

    Slice.new(@pointer + offset, @length - offset)
  end

  # Returns the element at the given *index*.
  #
  # Negative indices can be used to start counting from the end of the slice.
  # Raises `IndexError` if trying to access an element outside the slice's range.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice[0]  #=> 10
  # slice[4]  #=> 14
  # slice[-1] #=> 14
  # slice[5]  #=> IndexError
  # ```
  def [](index : Int)
    at(index)
  end

  # Sets the given value at the given index.
  #
  # Negative indices can be used to start counting from the end of the slice.
  # Raises `IndexError` if trying to set an element outside the slice's range.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice[0] = 20
  # slice[-1] = 30
  # slice #=> [20, 11, 12, 13, 30]
  #
  # slice[4] = 1 #=> IndexError
  # ```
  def []=(index : Int, value : T)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexError.new
    end

    @pointer[index] = value
  end

  # Returns a new slice that starts at *start* elements from this slice's start,
  # and of *count* length.
  #
  # Raises `IndexError` if the new slice falls outside this slice.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice #=> [10, 11, 12, 13, 14]
  #
  # slice2 = slice[1, 3]
  # slice2 #=> [11, 12, 13]
  # ```
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
