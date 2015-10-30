# A fixed-size, stack allocated array.
struct StaticArray(T, N)
  include Enumerable(T)

  # Creates a new static array and invokes the
  # block once for each index of the array, assigning the
  # block's value in that index.
  #
  # ```
  # StaticArray(Int32, 3).new { |i| i * 2 } # => [0, 2, 4]
  # ```
  def self.new(&block : Int32 -> T)
    array :: self
    N.times do |i|
      array.buffer[i] = yield i
    end
    array
  end

  # Creates a new static array filled with the given value.
  #
  # ```
  # StaticArray(Int32, 3).new(42) # => [42, 42, 42]
  # ```
  def self.new(value : T)
    new { value }
  end

  def ==(other : StaticArray)
    return false unless size == other.size
    each_with_index do |e, i|
      return false unless e == other[i]
    end
    true
  end

  def ==(other)
    false
  end

  def each
    N.times do |i|
      yield buffer[i]
    end
  end

  @[AlwaysInline]
  def [](index : Int)
    index = check_index_out_of_bounds index
    buffer[index]
  end

  @[AlwaysInline]
  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    buffer[index] = value
  end

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # a = StaticArray(Int32, 4).new { |i| i + 1 }
  # a.values_at(0, 2) # => {1, 3}
  # ```
  def values_at(*indexes : Int)
    indexes.map { |index| self[index] }
  end

  def update(index : Int)
    index = check_index_out_of_bounds index
    buffer[index] = yield buffer[index]
  end

  def size
    N
  end

  def []=(value : T)
    size.times do |i|
      buffer[i] = value
    end
  end

  def shuffle!
    buffer.shuffle!(size)
    self
  end

  def map!
    buffer.map!(size) { |e| yield e }
    self
  end

  def reverse!
    i = 0
    j = size - 1
    while i < j
      buffer.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def buffer
    pointerof(@buffer)
  end

  def to_slice
    Slice.new(buffer, size)
  end

  def to_unsafe
    buffer
  end

  def to_s(io : IO)
    io << "["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  private def check_index_out_of_bounds(index)
    index += size if index < 0
    unless 0 <= index < size
      raise IndexError.new
    end
    index
  end
end
