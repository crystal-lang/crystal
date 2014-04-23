class BitArray
  include Enumerable(Bool)

  def initialize(@length)
    @bits = Pointer(UInt32).malloc((length / 32.0).ceil)
  end

  def [](index)
    index += @length if index < 0
    raise IndexOutOfBounds.new if index >= @length || index < 0

    bit_index, sub_index = index.divmod(32)
    (@bits[bit_index] & (1 << sub_index)) > 0
  end

  def []=(index, value : Bool)
    index += @length if index < 0
    raise IndexOutOfBounds.new if index >= @length || index < 0

    bit_index, sub_index = index.divmod(32)
    if value
      @bits[bit_index] |= 1 << sub_index
    else
      @bits[bit_index] &= (UInt32::MAX - (1 << sub_index))
    end
  end

  def length
    @length
  end

  def each
    @length.times do |i|
      yield self[i]
    end
  end

  def to_s
    String.build do |str|
      str << "BitArray["
      each do |value|
        str << (value ? "1" : "0")
      end
      str << "]"
    end
  end
end
