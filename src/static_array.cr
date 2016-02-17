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
    array = uninitialized self
    N.times do |i|
      array.to_unsafe[i] = yield i
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
      yield to_unsafe[i]
    end
  end

  @[AlwaysInline]
  def [](index : Int)
    index = check_index_out_of_bounds index
    to_unsafe[index]
  end

  @[AlwaysInline]
  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    to_unsafe[index] = value
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
    to_unsafe[index] = yield to_unsafe[index]
  end

  def size
    N
  end

  def []=(value : T)
    size.times do |i|
      to_unsafe[i] = value
    end
  end

  def shuffle!
    to_unsafe.shuffle!(size)
    self
  end

  def map!
    to_unsafe.map!(size) { |e| yield e }
    self
  end

  def reverse!
    i = 0
    j = size - 1
    while i < j
      to_unsafe.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def to_slice
    Slice.new(to_unsafe, size)
  end

  def hash
    reduce(31 * size) do |memo, elem|
      31 * memo + elem.hash
    end
  end

  # Returns a pointer to this static array's data.
  #
  # ```
  # ary = StaticArray(Int32, 3).new(42)
  # ary.to_unsafe[0] # => 42
  # ```
  def to_unsafe : Pointer(T)
    pointerof(@buffer)
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
