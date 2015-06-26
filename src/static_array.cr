struct StaticArray(T, N)
  include Enumerable(T)

  # Creates a new static array and invokes the
  # block once for each index of the array, assigning the
  # block's value in that index.
  #
  # ```
  # StaticArray(Int32, 3).new { |i| i * 2 } #=> [0, 2, 4]
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
  # StaticArray(Int32, 3).new(42) #=> [42, 42, 42]
  # ```
  def self.new(value : T)
    new { value }
  end

  def each
    N.times do |i|
      yield buffer[i]
    end
  end

  def [](index : Int)
    index = check_index_out_of_bounds index
    buffer[index]
  end

  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    buffer[index] = value
  end

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # a = StaticArray(Int32, 4).new { |i| i + 1 }
  # a.values_at(0, 2) #=> {1, 3}
  # ```
  def values_at(*indexes : Int)
    indexes.map {|index| self[index] }
  end

  def update(index : Int)
    index = check_index_out_of_bounds index
    buffer[index] = yield buffer[index]
  end

  def length
    N
  end

  def count
    length
  end

  def size
    length
  end

  def []=(value : T)
    length.times do |i|
      buffer[i] = value
    end
  end

  def shuffle!
    buffer.shuffle!(length)
    self
  end

  def map!
    buffer.map!(length) { |e| yield e }
    self
  end

  def buffer
    pointerof(@buffer)
  end

  def to_slice
    Slice.new(buffer, length)
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
    index += length if index < 0
    unless 0 <= index < length
      raise IndexError.new
    end
    index
  end
end
