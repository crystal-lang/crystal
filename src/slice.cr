require "c/string"

# A `Slice` is a `Pointer` with an associated size.
#
# While a pointer is unsafe because no bound checks are performed when reading from and writing to it,
# reading from and writing to a slice involve bound checks.
# In this way, a slice is a safe alternative to `Pointer`.
#
# A Slice can be created as read-only: trying to write to it
# will raise. For example the slice of bytes returned by
# `String#to_slice` is read-only.
struct Slice(T)
  include Indexable(T)

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
  # If `T` is a `Number` then this is equivalent to
  # `Number.slice` (numbers will be coerced to the type `T`)
  #
  # See also: `Number.slice`.
  macro [](*args, read_only = false)
    # TODO: there should be a better way to check this, probably
    # asking if @type was instantiated or if T is defined
    {% if @type.name != "Slice(T)" && T < Number %}
      {{T}}.slice({{*args}}, read_only: {{read_only}})
    {% else %}
      %ptr = Pointer(typeof({{*args}})).malloc({{args.size}})
      {% for arg, i in args %}
        %ptr[{{i}}] = {{arg}}
      {% end %}
      Slice.new(%ptr, {{args.size}}, read_only: {{read_only}})
    {% end %}
  end

  # Returns the size of this slice.
  #
  # ```
  # Slice(UInt8).new(3).size # => 3
  # ```
  getter size : Int32

  # Returns `true` if this slice cannot be written to.
  getter? read_only : Bool

  # Creates a slice to the given *pointer*, bounded by the given *size*. This
  # method does not allocate heap memory.
  #
  # ```
  # ptr = Pointer.malloc(9) { |i| ('a'.ord + i).to_u8 }
  #
  # slice = Slice.new(ptr, 3)
  # slice.size # => 3
  # slice      # => Bytes[97, 98, 99]
  #
  # String.new(slice) # => "abc"
  # ```
  def initialize(@pointer : Pointer(T), size : Int, *, @read_only = false)
    @size = size.to_i32
  end

  # Allocates `size * sizeof(T)` bytes of heap memory initialized to zero
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # Only works for primitive integers and floats (`UInt8`, `Int32`, `Float64`, etc.)
  #
  # ```
  # slice = Slice(UInt8).new(3)
  # slice # => Bytes[0, 0, 0]
  # ```
  def self.new(size : Int, *, read_only = false)
    {% unless T <= Int::Primitive || T <= Float::Primitive %}
      {% raise "Can only use primitive integers and floats with Slice.new(size), not #{T}" %}
    {% end %}

    pointer = Pointer(T).malloc(size)
    new(pointer, size, read_only: read_only)
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
  # slice # => Slice[10, 11, 12]
  # ```
  def self.new(size : Int, *, read_only = false)
    pointer = Pointer.malloc(size) { |i| yield i }
    new(pointer, size, read_only: read_only)
  end

  # Allocates `size * sizeof(T)` bytes of heap memory initialized to *value*
  # and returns a slice pointing to that memory.
  #
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # slice = Slice.new(3, 10)
  # slice # => Slice[10, 10, 10]
  # ```
  def self.new(size : Int, value : T, *, read_only = false)
    new(size, read_only: read_only) { value }
  end

  # Returns a copy of this slice.
  # This method allocates memory for the slice copy.
  def clone
    copy = self.class.new(size)
    copy.copy_from(self)
    copy
  end

  # Creates an empty slice.
  #
  # ```
  # slice = Slice(UInt8).empty
  # slice.size # => 0
  # ```
  def self.empty
    new(Pointer(T).null, 0)
  end

  # Returns a new slice that is *offset* elements apart from this slice.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice # => Slice[10, 11, 12, 13, 14]
  #
  # slice2 = slice + 2
  # slice2 # => Slice[12, 13, 14]
  # ```
  def +(offset : Int)
    unless 0 <= offset <= size
      raise IndexError.new
    end

    Slice.new(@pointer + offset, @size - offset, read_only: @read_only)
  end

  # Sets the given value at the given *index*.
  #
  # Negative indices can be used to start counting from the end of the slice.
  # Raises `IndexError` if trying to set an element outside the slice's range.
  #
  # ```
  # slice = Slice.new(5) { |i| i + 10 }
  # slice[0] = 20
  # slice[-1] = 30
  # slice # => Slice[20, 11, 12, 13, 30]
  #
  # slice[10] = 1 # raises IndexError
  # ```
  @[AlwaysInline]
  def []=(index : Int, value : T)
    check_writable

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
  # slice # => Slice[10, 11, 12, 13, 14]
  #
  # slice2 = slice[1, 3]
  # slice2 # => Slice[11, 12, 13]
  # ```
  def [](start, count)
    unless 0 <= start <= @size
      raise IndexError.new
    end

    unless 0 <= count <= @size - start
      raise IndexError.new
    end

    Slice.new(@pointer + start, count, read_only: @read_only)
  end

  @[AlwaysInline]
  def unsafe_at(index : Int)
    @pointer[index]
  end

  # Reverses in-place all the elements of `self`.
  def reverse!
    check_writable

    i = 0
    j = size - 1
    while i < j
      @pointer.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def pointer(size)
    unless 0 <= size <= @size
      raise IndexError.new
    end

    @pointer
  end

  def shuffle!(random = Random::DEFAULT)
    check_writable

    @pointer.shuffle!(size, random)
  end

  def copy_from(source : Pointer(T), count)
    check_writable

    pointer(count).copy_from(source, count)
  end

  def copy_to(target : Pointer(T), count)
    pointer(count).copy_to(target, count)
  end

  # Copies the contents of this slice into *target*.
  #
  # Raises `IndexError` if the desination slice cannot fit the data being transferred
  # e.g. dest.size < self.size.
  #
  # ```
  # src = Slice['a', 'a', 'a']
  # dst = Slice['b', 'b', 'b', 'b', 'b']
  # src.copy_to dst
  # dst             # => Slice['a', 'a', 'a', 'b', 'b']
  # dst.copy_to src # raises IndexError
  # ```
  def copy_to(target : self)
    target.check_writable

    @pointer.copy_to(target.pointer(size), size)
  end

  # Copies the contents of *source* into this slice.
  #
  # Raises `IndexError` if the desination slice cannot fit the data being transferred.
  @[AlwaysInline]
  def copy_from(source : self)
    source.copy_to(self)
  end

  def move_from(source : Pointer(T), count)
    check_writable

    pointer(count).move_from(source, count)
  end

  def move_to(target : Pointer(T), count)
    pointer(count).move_to(target, count)
  end

  # Moves the contents of this slice into *target*. *target* and `self` may
  # overlap; the copy is always done in a non-destructive manner.
  #
  # Raises `IndexError` if the desination slice cannot fit the data being transferred
  # e.g. `dest.size < self.size`.
  #
  # ```
  # src = Slice['a', 'a', 'a']
  # dst = Slice['b', 'b', 'b', 'b', 'b']
  # src.move_to dst
  # dst             # => Slice['a', 'a', 'a', 'b', 'b']
  # dst.move_to src # raises IndexError
  # ```
  #
  # See also: `Pointer#move_to`.
  def move_to(target : self)
    target.check_writable

    @pointer.move_to(target.pointer(size), size)
  end

  # Moves the contents of *source* into this slice. *source* and `self` may
  # overlap; the copy is always done in a non-destructive manner.
  #
  # Raises `IndexError` if the desination slice cannot fit the data being transferred.
  @[AlwaysInline]
  def move_from(source : self)
    source.move_to(self)
  end

  def inspect(io)
    to_s(io)
  end

  # Returns a hexstring representation of this slice, assuming it's
  # a `Slice(UInt8)`.
  #
  # ```
  # slice = UInt8.slice(97, 62, 63, 8, 255)
  # slice.hexstring # => "613e3f08ff"
  # ```
  def hexstring
    self.as(Slice(UInt8))

    str_size = size * 2
    String.new(str_size) do |buffer|
      hexstring(buffer)
      {str_size, str_size}
    end
  end

  # :nodoc:
  def hexstring(buffer)
    self.as(Slice(UInt8))

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
  # slice.hexdump # => "00000000  61 3e 3f 08 ff                                    a>?.."
  # ```
  def hexdump
    self.as(Slice(UInt8))

    return "" if empty?

    full_lines, leftover = size.divmod(16)
    if leftover == 0
      str_size = full_lines * 77 - 1
      lines = full_lines
    else
      str_size = (full_lines + 1) * 77 - (16 - leftover) - 1
      lines = full_lines + 1
    end

    String.new(str_size) do |buf|
      index_offset = 0
      hex_offset = 10
      ascii_offset = 60

      # Ensure we don't write outside the buffer:
      # slower, but safer (speed is not very important when hexdump is used)
      buffer = Slice.new(buf, str_size)

      each_with_index do |v, i|
        if i % 16 == 0
          0.upto(7) do |j|
            buffer[index_offset + 7 - j] = to_hex((i >> (4 * j)) & 0xf)
          end
          buffer[index_offset + 8] = ' '.ord.to_u8
          buffer[index_offset + 9] = ' '.ord.to_u8
          index_offset += 77
        end

        buffer[hex_offset] = to_hex(v >> 4)
        buffer[hex_offset + 1] = to_hex(v & 0x0f)
        buffer[hex_offset + 2] = ' '.ord.to_u8
        hex_offset += 3

        buffer[ascii_offset] = (v > 31 && v < 127) ? v : '.'.ord.to_u8
        ascii_offset += 1

        if i % 8 == 7
          buffer[hex_offset] = ' '.ord.to_u8
          hex_offset += 1
        end

        if i % 16 == 15 && ascii_offset < str_size
          buffer[ascii_offset] = '\n'.ord.to_u8
          hex_offset += 27
          ascii_offset += 61
        end
      end

      while hex_offset % 77 < 60
        buffer[hex_offset] = ' '.ord.to_u8
        hex_offset += 1
      end

      {str_size, str_size}
    end
  end

  private def to_hex(c)
    ((c < 10 ? 48_u8 : 87_u8) + c)
  end

  def bytesize
    sizeof(T) * size
  end

  def ==(other : self)
    return false if bytesize != other.bytesize
    return LibC.memcmp(to_unsafe.as(Void*), other.to_unsafe.as(Void*), bytesize) == 0
  end

  def to_slice
    self
  end

  def to_s(io)
    if T == UInt8
      io << "Bytes"
      io << "["
      # Inspect using to_s because we know this is a UInt8.
      join ", ", io, &.to_s(io)
      io << "]"
    else
      io << "Slice"
      io << "["
      join ", ", io, &.inspect(io)
      io << "]"
    end
  end

  def pretty_print(pp) : Nil
    prefix = T == UInt8 ? "Bytes[" : "Slice["
    pp.list(prefix, self, "]")
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
  def index(object, offset : Int = 0)
    # Optimize for the case of looking for a byte in a byte slice
    if T.is_a?(UInt8.class) &&
       (object.is_a?(UInt8) || (object.is_a?(Int) && 0 <= object < 256))
      return fast_index(object, offset)
    end

    super
  end

  # :nodoc:
  def fast_index(object, offset)
    offset += size if offset < 0
    if 0 <= offset < size
      result = LibC.memchr(to_unsafe + offset, object, size - offset)
      if result
        return (result - to_unsafe.as(Void*)).to_i32
      end
    end

    nil
  end

  protected def check_writable
    raise "Can't write to read-only Slice" if @read_only
  end
end

# A convenient alias for the most common slice type,
# a slice of bytes, used for example in `IO#read` and `IO#write`.
alias Bytes = Slice(UInt8)
