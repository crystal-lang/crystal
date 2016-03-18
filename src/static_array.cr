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

  # Equality. Returns *true* if each element in `self` is equal to each
  # corresponding element in *other*.
  #
  # ```
  # array = StaticArray(Int32, 3).new 0  # => [0, 0, 0]
  # array2 = StaticArray(Int32, 3).new 0 # => [0, 0, 0]
  # array3 = StaticArray(Int32, 3).new 1 # => [1, 1, 1]
  # array == array2                      # => true
  # array == array3                      # => false
  # ```
  def ==(other : StaticArray)
    return false unless size == other.size
    each_with_index do |e, i|
      return false unless e == other[i]
    end
    true
  end

  # Equality with another object. Always returns *false*.
  #
  # ```
  # array = StaticArray(Int32, 3).new 0 # => [0, 0, 0]
  # array == nil                        # => false
  # ```
  def ==(other)
    false
  end

  # Calls the given block once for each element in `self`, passing that element as a parameter
  #
  # ```
  # array = StaticArray(Int32, 3).new 0     # => [0, 0, 0]
  # puts array.each { |x| print x, " -- " } # => 0 -- 0 -- 0 -- 3
  # ```
  def each
    N.times do |i|
      yield to_unsafe[i]
    end
  end

  # Returns the element at the given index.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 } # => [1 ,2 ,3]
  # array[0]                                        # => 1
  # array[1]                                        # => 2
  # array[2]                                        # => 3
  # array[4]                                        # => IndexError
  # ```
  @[AlwaysInline]
  def [](index : Int)
    index = check_index_out_of_bounds index
    to_unsafe[index]
  end

  # Sets the given value at the given index.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 } # => [1, 2, 3]
  # array[2] = 2                                    # => [1, 2, 2]
  # array[4] = 4                                    # => IndexError
  # ```
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

  # Yields the current element at the given index and updates the value at the given index with the block's value
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 } # => [1, 2, 3]
  # array.update(1) { |x| x * 2 }                   # => [1, 4, 3]
  # array.update(5) { |x| x * 2 }                   # => IndexError
  # ```
  def update(index : Int)
    index = check_index_out_of_bounds index
    to_unsafe[index] = yield to_unsafe[index]
  end

  # Returns the size of `self`
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.size # => 3
  # ```
  def size
    N
  end

  # Fills the array by substituting all elements with the given value
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i+1 }
  # array[]= 2 # => [2, 2, 2]
  #
  # ```
  def []=(value : T)
    size.times do |i|
      to_unsafe[i] = value
    end
  end

  # Modifies `self` by randomizing the order of elements in the array
  # using the given *random* number generator.  Returns `self`.
  #
  # ```
  # a = StaticArray(Int32, 3).new { |i| i + 1 } # => [1, 2, 3]
  # a.shuffle!(Random.new(42))                  # => [3, 2, 1]
  # a                                           # => [3, 2, 1]
  # ```
  def shuffle!(random = Random::DEFAULT)
    to_unsafe.shuffle!(size, random)
    self
  end

  # Invokes the given block for each element of `self`, replacing the element
  # with the value returned by the block. Returns `self`.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.map! { |x| x*x } # => [1, 4, 9]
  # ```
  def map!
    to_unsafe.map!(size) { |e| yield e }
    self
  end

  # Reverses the elements of this array in-place, then returns `self`
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.reverse! # => [3, 2, 1]
  # ```
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

  # Returns a slice that points to the elements of this static array.
  # Changes made to the returned slice also affect this static array.
  #
  # ```
  # array = StaticArray(Int32, 3).new(2)
  # slice = array.to_slice # => [2, 2, 2]
  # slice[0] = 3
  # array # => [3, 2, 2]
  # ```
  def to_slice
    Slice.new(to_unsafe, size)
  end

  # Returns a hash code based on `self`'s size and elements.
  #
  # See `Object#hash`.
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

  # Appends a string representation of this static array to the given IO.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.to_s # => "[1, 2, 3]"
  # ```
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
