# BitArray is an array data structure that compactly stores bits.
#
# Bits externally represented as `Bool`s and are stored internally as
# `UInt32`s. The total number of bits stored is set at creation and is
# immutable.
#
# `BitArray` includes all the methods in `Enumerable`.
#
# ### Example
#
#     require "bit_array"
#     ba = BitArray.new(12) # => "BitArray[000000000000]"
#     ba[2]                 # => false
#     0.upto(5) { |i| a[i*2] = true }
#     ba                    # => "BitArray[101010101010]"
#     ba[2]                 # => true
class BitArray
  include Enumerable(Bool)

  # The number of bits the BitArray stores
  getter length

  # Create a new BitArray of `length` bits.
  #
  # `initial` optionally sets the starting value, true or false, for all bits
  # in the array.
  def initialize(@length, initial = false : Bool)
    malloc_size = (length / 32.0).ceil.to_i
    if initial
      @bits = Pointer(UInt32).malloc(malloc_size, UInt32::MAX)
    else
      @bits = Pointer(UInt32).malloc(malloc_size)
    end
  end

  # Returns the bit at the given index.
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access a bit outside the array's range.
  #
  #     ba = BitArray.new(5)
  #     ba[3] # => false
  def [](index)
    bit_index, sub_index = bit_index_and_sub_index(index)
    (@bits[bit_index] & (1 << sub_index)) > 0
  end

  # Sets the bit at the given index.
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access a bit outside the array's range.
  #
  #     ba = BitArray.new(5)
  #     ba[3] = true
  def []=(index, value : Bool)
    bit_index, sub_index = bit_index_and_sub_index(index)
    if value
      @bits[bit_index] |= 1 << sub_index
    else
      @bits[bit_index] &= ~(1 << sub_index)
    end
  end

  def each
    @length.times do |i|
      yield self[i]
    end
  end

  def to_s(io : IO)
    io << "BitArray["
    each do |value|
      io << (value ? "1" : "0")
    end
    io << "]"
  end

  private def bit_index_and_sub_index(index)
    index += @length if index < 0
    raise IndexError.new if index >= @length || index < 0

    index.divmod(32)
  end
end
