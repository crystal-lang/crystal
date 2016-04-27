require "c/string"

# A Slice is a `Pointer` with an associated size.
#
# While a pointer is unsafe because no bound checks are performed when reading from and writing to it,
# reading from and writing to a slice involve bound checks.
# In this way, a slice is a safe alternative to Pointer.
struct Slice(T)
  include Enumerable(T)
  include Iterable

  # Create a new `Slice` with the given *args*. The type of the
  # slice will be the union of the type of the given *args*.
  #
  # The slice is allocated on the heap.
  #
  # ```
  # slice = Slice[1, 'a']
  # slice[0]    # => 1
  # slice[1]    # => 'a'
  # slice.class # => Slice(Char | Int32)
  # ```
  #
  # See also: `Number.slice`.
  macro [](*args)
    slice = Slice(typeof({{*args}})).new({{args.size}})
    {% for arg, i in args %}
      slice.to_unsafe[{{i}}] = {{arg}}
    {% end %}
    slice
  end

  # Returns the size of this slice.
  #
  # ```
  # Slice(UInt8).new(3).size # => 3
  # ```
  getter size : Int32

  # Creates a slice to the given *pointer*, bounded by the given *size*. This
  # method does not allocate heap memory.
  #
  # ```
  # ptr = Pointer.malloc(9) { |i| ('a'.ord + i).to_u8 }
  #
  # slice = Slice.new(ptr, 3)
  # slice.size # => 3
  # slice      # => [97, 98, 99]
  #
  # String.new(slice) # => "abc"
  # ```
  def initialize(@pointer : Pointer(T), size : Int)
    @size = size.to_i32
  end

  # Allocates `size * sizeof(T)` bytes of heap memory initialized to zero
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice(UInt8).new(3)
  # slice # => [0, 0, 0]
  # ```
  def self.new(size : Int)
    pointer = Pointer(T).malloc(size)
    new(pointer, size)
  end

  # Allocates `size * sizeof(T)` bytes of heap memory initialized to the value
  # returned by the block (which is invoked once with each index in the range `0...size`)
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice.new(3) { |i| i + 10 }
  # slice # => [10, 11, 12]
  # ```
  def self.new(size : Int)
    pointer = Pointer.malloc(size) { |i| yield i }
    new(pointer, size)
  end

  # Allocates `size * sizeof(T)` bytes of heap memory initialized to *value*
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice.new(3, 10)
  # slice # => [10, 10, 10]
  # ```
  def self.new(size : Int, value : T)
    new(size) { value }
  end

  # Returns a new slice that i *offset* elements apart from this slice.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice # => [10, 11, 12, 13, 14]
  #
  # slice2 = slice + 2
  # slice2 # => [12, 13, 14]
  # ```
  def +(offset : Int)
    unless 0 <= offset <= size
      raise IndexError.new
    end

    Slice.new(@pointer + offset, @size - offset)
  end

  # Returns the element at the given *index*.
  #
  # Negative indices can be used to start counting from the end of the slice.
  # Raises `IndexError` if trying to access an element outside the slice's range.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice[0]  # => 10
  # slice[4]  # => 14
  # slice[-1] # => 14
  # slice[5]  # => IndexError
  # ```
  @[AlwaysInline]
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
  # slice # => [20, 11, 12, 13, 30]
  #
  # slice[4] = 1 # => IndexError
  # ```
  @[AlwaysInline]
  def []=(index : Int, value : T)
    index += size if index < 0
    unless 0 <= index < size
      raise IndexError.new
    end

    @pointer[index] = value
  end

  # Returns a new slice that starts at *start* elements from this slice's start,
  # and of *count* size.
  #
  # Raises `IndexError` if the new slice falls outside this slice.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice # => [10, 11, 12, 13, 14]
  #
  # slice2 = slice[1, 3]
  # slice2 # => [11, 12, 13]
  # ```
  def [](start, count)
    unless 0 <= start <= @size
      raise IndexError.new
    end

    unless 0 <= count <= @size - start
      raise IndexError.new
    end

    Slice.new(@pointer + start, count)
  end

  @[AlwaysInline]
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  def at(index : Int)
    index += size if index < 0
    if 0 <= index < size
      @pointer[index]
    else
      yield
    end
  end

  def empty?
    @size == 0
  end

  # Pass each element of slice to block.
  def each(&block)
    size.times do |i|
      yield @pointer[i]
    end

    self
  end

  def each
    ItemIterator(T).new(self)
  end

  # Same as `#each`, but works in reverse.
  def reverse_each(&block)
    (size - 1).downto(0) do |i|
      yield @pointer[i]
    end

    self
  end

  def reverse_each
    ReverseIterator(T).new(self)
  end

  def pointer(size)
    unless 0 <= size <= @size
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

  # Returns a hexstring representation of this slice, assuming it's
  # a `Slice(UInt8)`.
  #
  # ```
  # slice = UInt8.slice(97, 62, 63, 8, 255)
  # slice.hexstring # => "61626308ff"
  # ```
  def hexstring
    self as Slice(UInt8)

    str_size = size * 2
    String.new(str_size) do |buffer|
      hexstring(buffer)
      {str_size, str_size}
    end
  end

  # :nodoc:
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

  # Returns a hexdump of this slice, assuming it's a `Slice(UInt8)`.
  # This method is specially useful for debugging binary data and
  # incoming/outgoing data in protocols.
  #
  # ```
  # slice = UInt8.slice(97, 62, 63, 8, 255)
  # slice.hexdump # => "6162 6308 ff                             abc.."
  # ```
  def hexdump
    self as Slice(UInt8)

    full_lines, leftover = size.divmod(16)
    if leftover == 0
      str_size = full_lines*58 - 1
    else
      str_size = (full_lines + 1)*58 - (16 - leftover) - 1
    end

    String.new(str_size) do |buffer|
      hex_offset = 0
      ascii_offset = 41

      each_with_index do |v, i|
        buffer[hex_offset] = to_hex(v >> 4)
        buffer[hex_offset + 1] = to_hex(v & 0x0f)
        hex_offset += 2

        buffer[ascii_offset] = (v > 31 && v < 127) ? v : '.'.ord.to_u8
        ascii_offset += 1

        if i % 2 == 1
          buffer[hex_offset] = ' '.ord.to_u8
          hex_offset += 1
        end

        if i % 16 == 15
          buffer[hex_offset] = ' '.ord.to_u8
          buffer[ascii_offset] = '\n'.ord.to_u8
          ascii_offset += 42
          hex_offset += 18
        end
      end

      while hex_offset % 58 < 41
        buffer[hex_offset] = ' '.ord.to_u8
        hex_offset += 1
      end

      {str_size, str_size}
    end
  end

  def rindex(value)
    rindex { |elem| elem == value }
  end

  def rindex
    (size - 1).downto(0) do |i|
      if yield @pointer[i]
        return i
      end
    end
    nil
  end

  private def to_hex(c)
    ((c < 10 ? 48_u8 : 87_u8) + c)
  end

  def bytesize
    sizeof(T) * size
  end

  def ==(other : self)
    return false if bytesize != other.bytesize
    return LibC.memcmp(to_unsafe as Void*, other.to_unsafe as Void*, bytesize) == 0
  end

  def to_slice
    self
  end

  def to_s(io)
    io << "Slice["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def to_a
    Array(T).build(@size) do |pointer|
      pointer.copy_from(@pointer, @size)
      @size
    end
  end

  # Returns this slice's pointer.
  #
  # ```
  # slice = Slice.new(3, 10)
  # slice.to_unsafe[0] # => 10
  # ```
  def to_unsafe : Pointer(T)
    @pointer
  end

  # :nodoc:
  class ItemIterator(T)
    include Iterator(T)

    @slice : ::Slice(T)
    @index : Int32

    def initialize(@slice : ::Slice(T), @index = 0)
    end

    def next
      return stop if @index >= @slice.size
      @index += 1
      @slice.at(@index - 1)
    end

    def rewind
      @index = 0
      self
    end
  end

  class ReverseIterator(T)
    include Iterator(T)

    @slice : ::Slice(T)
    @index : Int32

    def initialize(@slice : ::Slice(T), @index = slice.size)
    end

    def next
      return stop if @index <= 0
      @index -= 1
      @slice.at(@index)
    end

    def rewind
      @index = @slice.size
      self
    end
  end
end
