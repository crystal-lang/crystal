struct StaticArray(T, N)
  include Enumerable(T)

  def self.new
    array :: self
    N.times do |i|
      array.buffer[i] = yield i
    end
    array
  end

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

  def update(index : Int)
    index = check_index_out_of_bounds index
    buffer[index] = yield buffer[index]
  end

  def length
    N
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
      raise IndexOutOfBounds.new
    end
    index
  end
end
