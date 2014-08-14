class BitArray
  include Enumerable(Bool)

  getter length

  def initialize(@length)
    @bits = Pointer(UInt32).malloc((length / 32.0).ceil)
  end

  def [](index)
    bit_index, sub_index = bit_index_and_sub_index(index)
    (@bits[bit_index] & (1 << sub_index)) > 0
  end

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
    raise IndexOutOfBounds.new if index >= @length || index < 0

    index.divmod(32)
  end
end
