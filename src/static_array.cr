# A fixed-size, stack allocated array.
struct StaticArray(T, N)
  include Enumerable(T)
  include Enumerable::FixedSizeCompare(T)
  include Iterable

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
    ItemIterator(T).new(buffer, N)
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

  def size
    N
  end

  def bytesize
    sizeof(T) * size
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

  # :nodoc:
  class ItemIterator(T)
    include Iterator(T)

    def initialize(@pointer, @size, @index = 0)
    end

    def next
      value = if @index < @size
        (@pointer + @index).value
      else
        stop
      end
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end
end
