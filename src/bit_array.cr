# `BitArray` is an array data structure that compactly stores bits.
#
# Bits externally represented as `Bool`s are stored internally as
# `UInt32`s. The total number of bits stored is set at creation and is
# immutable.
#
# ### Example
#
# ```
# require "bit_array"
#
# ba = BitArray.new(12) # => "BitArray[000000000000]"
# ba[2]                 # => false
# 0.upto(5) { |i| ba[i * 2] = true }
# ba    # => "BitArray[101010101010]"
# ba[2] # => true
# ```
struct BitArray
  include Indexable(Bool)

  @size : Int32
  @bits : UInt32*

  # The number of bits the BitArray stores
  def size
    # Optimization: the actual size must be non-negative, so we use negative
    # values to indicate small arrays that don't use the heap
    @size.abs
  end

  # Creates a new `BitArray` of *size* bits.
  #
  # *initial* optionally sets the starting value, `true` or `false`, for all bits
  # in the array.
  def initialize(size, initial : Bool = false)
    raise ArgumentError.new("Negative bit array size: #{size}") if size < 0

    # Optimization: if the bits fit into a pointer, we use the pointer itself to
    # store the bits directly
    if size <= sizeof(typeof(@bits))
      @size = -size
      @bits = Pointer(UInt32).new(initial ? ~(UInt64::MAX << size) : 0_u64)
    else
      @size = size
      value = initial ? UInt32::MAX : UInt32::MIN
      @bits = Pointer(UInt32).malloc(malloc_size, value)
      clear_unused_bits if initial
    end
  end

  def ==(other : BitArray)
    return false if @size != other.@size

    if small?
      @bits == other.@bits
    else
      # NOTE: If BitArray implements resizing, there may be more than 1 binary
      # representation and their hashes for equivalent BitArrays after a downsize as the
      # discarded bits may not have been zeroed.
      return LibC.memcmp(buffer, other.buffer, bytesize) == 0
    end
  end

  def unsafe_fetch(index : Int) : Bool
    bit_index, sub_index = index.divmod(32)
    (buffer[bit_index] & (1 << sub_index)) > 0
  end

  # Sets the bit at the given *index*.
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access a bit outside the array's range.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba[3] = true
  # ```
  def []=(index, value : Bool)
    bit_index, sub_index = bit_index_and_sub_index(index)
    if value
      buffer[bit_index] |= 1 << sub_index
    else
      buffer[bit_index] &= ~(1 << sub_index)
    end
  end

  # Returns all elements that are within the given range.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element). Additionally, an empty array is returned when the starting index
  # for an element range is at the end of the array.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba[0] = true; ba[2] = true; ba[4] = true
  # ba # => BitArray[10101]
  #
  # ba[1..3]    # => BitArray[010]
  # ba[4..7]    # => BitArray[1]
  # ba[6..10]   # raise IndexError
  # ba[5..10]   # => BitArray[]
  # ba[-2...-1] # => BitArray[0]
  # ```
  def [](range : Range) : BitArray
    self[*Indexable.range_to_index_and_count(range, size) || raise IndexError.new]
  end

  # Returns count or less (if there aren't enough) elements starting at the
  # given start index.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element). Additionally, an empty array is returned when the starting index
  # for an element range is at the end of the array.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba[0] = true; ba[2] = true; ba[4] = true
  # ba # => BitArray[10101]
  #
  # ba[-3, 3] # => BitArray[101]
  # ba[6, 1]  # raise indexError
  # ba[1, 2]  # => BitArray[01]
  # ba[5, 1]  # => BitArray[]
  # ```
  def [](start : Int, count : Int) : BitArray
    start, count = normalize_start_and_count(start, count)
    ba = BitArray.new(count)
    return ba if count == 0

    buffer = self.buffer

    if size <= 32
      # Result *and* original fit in a single int32, we can use only bitshifts
      bits = buffer[0]

      bits >>= start
      bits &= (1 << count) - 1

      ba.buffer[0] = bits
    elsif size <= 64
      # Original fits in int64, we can use bitshifts
      bits = buffer.as(UInt64*)[0]

      bits >>= start
      bits &= (1 << count) - 1

      if count <= 32
        ba.buffer[0] = bits.to_u32
      else
        ba.buffer.as(UInt64*)[0] = bits
      end
    else
      start_bit_index, start_sub_index = start.divmod(32)
      end_bit_index = (start + count) // 32

      i = 0
      bits = buffer[start_bit_index]
      while start_bit_index + i <= end_bit_index
        low_bits = bits
        low_bits >>= start_sub_index

        bits = buffer[start_bit_index + i + 1]

        high_bits = bits
        high_bits &= (1 << start_sub_index) - 1
        high_bits <<= 32 - start_sub_index

        ba.buffer[i] = low_bits | high_bits
        i += 1
      end

      # The last assignment to `bits` might refer to a `UInt32` in the middle of
      # the buffer, so the last `UInt32` of `ba` might contain unused bits.
      ba.clear_unused_bits
    end

    ba
  end

  # Toggles the bit at the given *index*. A `false` bit becomes a `true` bit,
  # and vice versa.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element).
  #
  # Raises `IndexError` if *index* is out of range.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba[3] # => false
  # ba.toggle(3)
  # ba[3] # => true
  # ```
  def toggle(index) : Nil
    bit_index, sub_index = bit_index_and_sub_index(index)
    buffer[bit_index] ^= 1 << sub_index
  end

  # Toggles all bits that are within the given *range*. A `false` bit becomes a
  # `true` bit, and vice versa.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element).
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba.to_s # => "BitArray[00000]"
  # ba.toggle(1..-2)
  # ba.to_s # => "BitArray[01110]"
  # ```
  def toggle(range : Range)
    toggle(*Indexable.range_to_index_and_count(range, size) || raise IndexError.new)
  end

  # Toggles *count* or less (if there aren't enough) bits starting at the given
  # *start* index. A `false` bit becomes a `true` bit, and vice versa.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element).
  #
  # Raises `IndexError` if *index* is out of range.
  # Raises `ArgumentError` if *count* is a negative number.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba.to_s # => "BitArray[00000]"
  # ba.toggle(1, 3)
  # ba.to_s # => "BitArray[01110]"
  # ```
  def toggle(start : Int, count : Int)
    start, count = normalize_start_and_count(start, count)

    start_bit_index, start_sub_index = start.divmod(32)
    end_bit_index, end_sub_index = (start + count - 1).divmod(32)
    buffer = self.buffer

    if start_bit_index == end_bit_index
      # same UInt32, don't perform the loop at all
      buffer[start_bit_index] ^= uint32_mask(start_sub_index, end_sub_index)
    else
      buffer[start_bit_index] ^= uint32_mask(start_sub_index, 31)
      (start_bit_index + 1..end_bit_index - 1).each do |i|
        buffer[i] = ~buffer[i]
      end
      buffer[end_bit_index] ^= uint32_mask(0, end_sub_index)
    end
  end

  # returns (1 << from) | (1 << (from + 1)) | ... | (1 << to)
  @[AlwaysInline]
  private def uint32_mask(from, to)
    (Int32::MIN >> (to - from)).to_u32! >> (31 - to)
  end

  # Inverts all bits in the array. Falses become `true` and vice versa.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba[2] = true; ba[3] = true
  # ba # => BitArray[00110]
  # ba.invert
  # ba # => BitArray[11001]
  # ```
  def invert : Nil
    buffer = self.buffer
    malloc_size.times do |i|
      buffer[i] = ~buffer[i]
    end
    clear_unused_bits
  end

  # Creates a string representation of self.
  #
  # ```
  # require "bit_array"
  #
  # ba = BitArray.new(5)
  # ba.to_s # => "BitArray[00000]"
  # ```
  def to_s(io : IO) : Nil
    io << "BitArray["
    each do |value|
      io << (value ? '1' : '0')
    end
    io << ']'
  end

  # :ditto:
  def inspect(io : IO) : Nil
    to_s(io)
  end

  # Returns a `Bytes` able to read and write bytes from a buffer.
  # The slice will be long enough to hold all the bits groups in bytes despite the `UInt32` internal representation.
  # It's useful for reading and writing a bit array from a byte buffer directly.
  #
  # WARNING: It is undefined behaviour to set any of the unused bits of a bit array to
  # `true` via a slice.
  def to_slice : Bytes
    Slice.new(buffer.as(Pointer(UInt8)), bytesize)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher = size.hash(hasher)
    hasher = to_slice.hash(hasher)
    hasher
  end

  # Returns a new `BitArray` with all of the same elements.
  def dup
    return super if small?

    bit_array = BitArray.new(@size)
    @bits.copy_to(bit_array.@bits, malloc_size)
    bit_array
  end

  private def bit_index_and_sub_index(index)
    bit_index_and_sub_index(index) { raise IndexError.new }
  end

  private def bit_index_and_sub_index(index)
    index = check_index_out_of_bounds(index) do
      return yield
    end
    index.divmod(32)
  end

  protected def clear_unused_bits
    # There are no unused bits if `size` is a multiple of 32.
    bit_index, sub_index = size.divmod(32)
    buffer[bit_index] &= (1 << sub_index) - 1 unless sub_index == 0
  end

  protected def buffer
    small? ? pointerof(@bits).unsafe_as(Pointer(UInt32)) : @bits
  end

  private def small?
    @size <= 0
  end

  private def bytesize
    (size - 1) // 8 + 1
  end

  private def malloc_size
    (size - 1) // 32 + 1
  end
end
