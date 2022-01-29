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
  include Indexable::Mutable(Bool)

  # The number of bits the BitArray stores
  getter size : Int32

  # Creates a new `BitArray` of *size* bits.
  #
  # *initial* optionally sets the starting value, `true` or `false`, for all bits
  # in the array.
  def initialize(@size, initial : Bool = false)
    value = initial ? UInt32::MAX : UInt32::MIN
    @bits = Pointer(UInt32).malloc(malloc_size, value)
    clear_unused_bits if initial
  end

  def ==(other : BitArray)
    return false if size != other.size
    # NOTE: If BitArray implements resizing, there may be more than 1 binary
    # representation and their hashes for equivalent BitArrays after a downsize as the
    # discarded bits may not have been zeroed.
    return LibC.memcmp(@bits, other.@bits, bytesize) == 0
  end

  def unsafe_fetch(index : Int) : Bool
    bit_index, sub_index = index.divmod(32)
    (@bits[bit_index] & (1 << sub_index)) > 0
  end

  def unsafe_put(index : Int, value : Bool)
    bit_index, sub_index = index.divmod(32)
    if value
      @bits[bit_index] |= 1 << sub_index
    else
      @bits[bit_index] &= ~(1 << sub_index)
    end
  end

  # :inherit:
  def []=(index : Int, value : Bool) : Bool
    bit_index, sub_index = bit_index_and_sub_index(index)
    if value
      @bits[bit_index] |= 1 << sub_index
    else
      @bits[bit_index] &= ~(1 << sub_index)
    end
    value
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

    if count == 0
      return BitArray.new(0)
    end

    if size <= 32
      # Result *and* original fit in a single int32, we can use only bitshifts
      bits = @bits[0]

      bits >>= start
      bits &= ~(UInt32::MAX << count)

      BitArray.new(count).tap { |ba| ba.@bits[0] = bits }
    elsif size <= 64
      # Original fits in int64, we can use bitshifts
      bits = @bits.as(UInt64*)[0]

      bits >>= start
      bits &= ~(UInt64::MAX << count)

      if count <= 32
        BitArray.new(count).tap { |ba| ba.@bits[0] = bits.to_u32! }
      else
        BitArray.new(count).tap { |ba| ba.@bits.as(UInt64*)[0] = bits }
      end
    else
      ba = BitArray.new(count)
      start_bit_index, start_sub_index = start.divmod(32)
      end_bit_index = (start + count) // 32

      i = 0
      bits = @bits[start_bit_index]
      while start_bit_index + i <= end_bit_index
        low_bits = bits
        low_bits >>= start_sub_index

        bits = @bits[start_bit_index + i + 1]

        high_bits = bits
        high_bits &= ~(UInt32::MAX << start_sub_index)
        high_bits <<= 32 - start_sub_index

        ba.@bits[i] = low_bits | high_bits
        i += 1
      end

      # The last assignment to `bits` might refer to a `UInt32` in the middle of
      # the buffer, so the last `UInt32` of `ba` might contain unused bits.
      ba.clear_unused_bits
      ba
    end
  end

  # :inherit:
  def all? : Bool
    bit_index, sub_index = @size.divmod(32)

    bit_index.times do |i|
      return false unless @bits[i] == UInt32::MAX
    end

    return true if sub_index == 0
    mask = ~(UInt32::MAX << sub_index)
    @bits[bit_index] & mask == mask
  end

  # :inherit:
  def any? : Bool
    Slice.new(@bits, malloc_size).any? { |bits| bits != 0 }
  end

  # :inherit:
  def none? : Bool
    !any?
  end

  # Returns `true` if the collection contains *obj*, `false` otherwise.
  #
  # ```
  # ba = BitArray.new(8, true)
  # ba.includes?(true)  # => true
  # ba.includes?(false) # => false
  # ```
  def includes?(obj : Bool) : Bool
    obj ? any? : !all?
  end

  # :inherit:
  def one? : Bool
    c = 0
    malloc_size.times do |i|
      c += @bits[i].popcount
      return false if c > 1
    end
    c == 1
  end

  # Returns the number of times that *item* is present in the bit array.
  #
  # ```
  # ba = BitArray.new(12, true)
  # ba[3] = false
  # ba[7] = false
  # ba.count(true)  # => 10
  # ba.count(false) # => 2
  # ```
  def count(item : Bool) : Int32
    ones_count = Slice.new(@bits, malloc_size).sum(&.popcount)
    item ? ones_count : @size - ones_count
  end

  # :inherit:
  def tally : Hash(Bool, Int32)
    tallies = Hash(Bool, Int32).new
    ones_count = count(true)
    tallies[true] = ones_count if ones_count > 0
    tallies[false] = @size - ones_count if ones_count < @size
    tallies
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
    @bits[bit_index] ^= 1 << sub_index
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
    return if count == 0

    start_bit_index, start_sub_index = start.divmod(32)
    end_bit_index, end_sub_index = (start + count - 1).divmod(32)

    if start_bit_index == end_bit_index
      # same UInt32, don't perform the loop at all
      @bits[start_bit_index] ^= uint32_mask(start_sub_index, end_sub_index)
    else
      @bits[start_bit_index] ^= uint32_mask(start_sub_index, 31)
      (start_bit_index + 1..end_bit_index - 1).each do |i|
        @bits[i] = ~@bits[i]
      end
      @bits[end_bit_index] ^= uint32_mask(0, end_sub_index)
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
    malloc_size.times do |i|
      @bits[i] = ~@bits[i]
    end
    clear_unused_bits
  end

  # :inherit:
  def reverse! : self
    return self if size <= 1

    if size <= 32
      @bits.value = Intrinsics.bitreverse32(@bits.value) >> (32 - size)
    elsif size <= 64
      more_bits = @bits.as(UInt64*)
      more_bits.value = Intrinsics.bitreverse64(more_bits.value) >> (64 - size)
    else
      # 3 or more groups of bits
      offset = (-size) % 32
      if offset != 0
        # left-shifting, followed by bit-reversing in each group
        # simplified bit pattern example using a group size of 8: (offset = 3)
        #
        #     hgfedcba ponmlkji 000utsrq
        #     hgfedcba ponmlkji utsrqpon
        #     hgfedcba ponmlkji nopqrstu
        #     hgfedcba mlkjihgf nopqrstu
        #     hgfedcba fghijklm nopqrstu
        (malloc_size - 1).downto(1) do |i|
          @bits[i] = Intrinsics.bitreverse32((@bits[i] << offset) | (@bits[i - 1] >> (32 - offset)))
        end

        # last group:
        #
        #     edcba000 fghijklm nopqrstu
        #     000abcde fghijklm nopqrstu
        @bits[0] = Intrinsics.bitreverse32(@bits[0] << offset)
      else
        # no padding; do only the bit reverses
        Slice.new(@bits, malloc_size).map! { |x| Intrinsics.bitreverse32(x) }
      end

      # reversing all groups themselves:
      #
      #     nopqrstu fghijklm 000abcde
      Slice.new(@bits, malloc_size).reverse!
    end

    self
  end

  # :inherit:
  def rotate!(n : Int = 1) : self
    return self if size <= 1
    n %= size
    return self if n == 0

    if size % 8 == 0 && n % 8 == 0
      to_slice.rotate!(n // 8)
    elsif size <= 32
      @bits[0] = (@bits[0] >> n) | (@bits[0] << (size - n))
      clear_unused_bits
    elsif n <= 32
      temp = @bits[0]
      malloc_size = self.malloc_size
      (malloc_size - 1).times do |i|
        @bits[i] = (@bits[i] >> n) | (@bits[i + 1] << (32 - n))
      end

      end_sub_index = (size - 1) % 32 + 1
      if n <= end_sub_index
        # n = 3: (bit patterns here are little-endian)
        #
        #     ........ ........ ........ .....CBA -> ........ ........ ........ ........
        #     ........ ........ ........ ........ -> cba..... ........ ........ ........
        #     00000000 00000000 00000000 000edcba -> 00000000 00000000 00000000 000CBAed
        @bits[malloc_size - 1] = (@bits[malloc_size - 1] >> n) | (temp << (end_sub_index - n))
      else
        # n = 7:
        #
        #     ........ ........ ........ .GFEDCBA -> ........ ........ ........ ........
        #     ........ ........ ........ ........ -> BAedcba. ........ ........ ........
        #     00000000 00000000 00000000 000edcba -> 00000000 00000000 00000000 000GFEDC
        @bits[malloc_size - 2] |= temp << (32 + end_sub_index - n)
        @bits[malloc_size - 1] = temp << (end_sub_index - n)
      end

      clear_unused_bits
    elsif n >= size - 32
      n = size - n
      malloc_size = self.malloc_size

      end_sub_index = (size - 1) % 32 + 1
      if n <= end_sub_index
        # n = 3:
        #
        #     ........ ........ ........ ........ -> ........ ........ ........ .....CBA
        #     00000000 00000000 00000000 000CBA.. -> 00000000 00000000 00000000 000.....
        temp = @bits[malloc_size - 1] >> (end_sub_index - n)
      else
        # n = 7:
        #
        #     BA...... ........ ........ ........ -> ........ ........ ........ .GFEDCBA
        #     00000000 00000000 00000000 000GFEDC -> 00000000 00000000 00000000 000.....
        temp = (@bits[malloc_size - 1] << (n - end_sub_index)) | (@bits[malloc_size - 2] >> (32 + end_sub_index - n))
      end

      (malloc_size - 1).downto(1) do |i|
        @bits[i] = (@bits[i] << n) | (@bits[i - 1] >> (32 - n))
      end
      @bits[0] = (@bits[0] << n) | temp

      clear_unused_bits
    else
      super
    end

    self
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
    Slice.new(@bits.as(Pointer(UInt8)), bytesize)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher = size.hash(hasher)
    hasher = to_slice.hash(hasher)
    hasher
  end

  # Returns a new `BitArray` with all of the same elements.
  def dup
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
    bit_index, sub_index = @size.divmod(32)
    @bits[bit_index] &= ~(UInt32::MAX << sub_index) unless sub_index == 0
  end

  private def bytesize
    (@size - 1) // 8 + 1
  end

  private def malloc_size
    (@size - 1) // 32 + 1
  end
end
