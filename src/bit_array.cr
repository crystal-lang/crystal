# BitArray is an array data structure that compactly stores bits.
#
# Bits externally represented as `Bool`s are stored internally as
# `UInt32`s. The total number of bits stored is set at creation and is
# immutable.
#
# `BitArray` includes all the methods in `Enumerable`.
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

  # The number of bits the BitArray stores
  getter size : Int32

  # Create a new `BitArray` of *size* bits.
  #
  # *initial* optionally sets the starting value, `true` or `false`, for all bits
  # in the array.
  def initialize(@size, initial : Bool = false)
    value = initial ? UInt32::MAX : UInt32::MIN
    @bits = Pointer(UInt32).malloc(malloc_size, value)
  end

  def ==(other : BitArray)
    return false if size != other.size
    # NOTE: If BitArray implements resizing, there may be more than 1 binary
    # representation for equivalent BitArrays after a downsize as the discarded
    # bits may not have been zeroed.
    return LibC.memcmp(@bits, other.@bits, malloc_size) == 0
  end

  def ==(other)
    false
  end

  def unsafe_at(index : Int)
    bit_index, sub_index = index.divmod(32)
    (@bits[bit_index] & (1 << sub_index)) > 0
  end

  # Sets the bit at the given *index*.
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access a bit outside the array's range.
  #
  # ```
  # ba = BitArray.new(5)
  # ba[3] = true
  # ```
  def []=(index, value : Bool)
    bit_index, sub_index = bit_index_and_sub_index(index)
    if value
      @bits[bit_index] |= 1 << sub_index
    else
      @bits[bit_index] &= ~(1 << sub_index)
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
  def [](range : Range(Int, Int))
    self[*Indexable.range_to_index_and_count(range, size)]
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
  # ba = BitArray.new(5)
  # ba[0] = true; ba[2] = true; ba[4] = true
  # ba # => BitArray[10101]
  #
  # ba[-3, 3] # => BitArray[101]
  # ba[6, 1]  # raise indexError
  # ba[1, 2]  # => BitArray[01]
  # ba[5, 1]  # => BitArray[]
  # ```
  def [](start : Int, count : Int)
    raise ArgumentError.new "Negative count: #{count}" if count < 0

    if start == size
      return BitArray.new(0)
    end

    start += size if start < 0
    raise IndexError.new unless 0 <= start <= size

    if count == 0
      return BitArray.new(0)
    end

    count = Math.min(count, size - start)

    if size <= 32
      # Result *and* original fit in a single int32, we can use only bitshifts
      bits = @bits[0]

      bits >>= start
      bits &= (1 << count) - 1

      BitArray.new(count).tap { |ba| ba.@bits[0] = bits }
    elsif size <= 64
      # Original fits in int64, we can use bitshifts
      bits = @bits.as(UInt64*)[0]

      bits >>= start
      bits &= (1 << count) - 1

      if count <= 32
        BitArray.new(count).tap { |ba| ba.@bits[0] = bits.to_u32 }
      else
        BitArray.new(count).tap { |ba| ba.@bits.as(UInt64*)[0] = bits }
      end
    else
      ba = BitArray.new(count)
      start_bit_index, start_sub_index = start.divmod(32)
      end_bit_index = (start + count) / 32

      i = 0
      bits = @bits[start_bit_index]
      while start_bit_index + i <= end_bit_index
        low_bits = bits
        low_bits >>= start_sub_index

        bits = @bits[start_bit_index + i + 1]

        high_bits = bits
        high_bits &= (1 << start_sub_index) - 1
        high_bits <<= 32 - start_sub_index

        ba.@bits[i] = low_bits | high_bits
        i += 1
      end

      ba
    end
  end

  # Toggles the bit at the given *index*. A false bit becomes a `true` bit, and
  # vice versa.
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access a bit outside the array's range.
  #
  # ```
  # ba = BitArray.new(5)
  # ba[3] # => false
  # ba.toggle(3)
  # ba[3] # => true
  # ```
  def toggle(index)
    bit_index, sub_index = bit_index_and_sub_index(index)
    @bits[bit_index] ^= 1 << sub_index
  end

  # Inverts all bits in the array. Falses become `true` and vice versa.
  #
  # ```
  # ba = BitArray.new(5)
  # ba[2] = true; ba[3] = true
  # ba # => BitArray[00110]
  # ba.invert
  # ba # => BitArray[11001]
  # ```
  def invert
    malloc_size.times do |i|
      @bits[i] = ~@bits[i]
    end
  end

  # Creates a string representation of self.
  #
  # ```
  # ba = BitArray.new(5)
  # ba.to_s # => "BitArray[00000]"
  # ```
  def to_s(io : IO)
    io << "BitArray["
    each do |value|
      io << (value ? "1" : "0")
    end
    io << "]"
  end

  # ditto
  def inspect(io : IO)
    to_s(io)
  end

  # Returns a `Bytes` able to read and write bytes from a buffer.
  # The slice will be long enough to hold all the bits groups in bytes despite the `UInt32` internal representation.
  # It's useful for reading and writing a bit array from a byte buffer directly.
  def to_slice : Bytes
    Slice.new(@bits.as(Pointer(UInt8)), (@size / 8.0).ceil.to_i)
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

  private def malloc_size
    (@size / 32.0).ceil.to_i
  end
end
