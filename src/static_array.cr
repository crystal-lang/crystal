# A fixed-size, stack allocated array.
struct StaticArray(T, N)
  include Indexable(T)

  # Create a new `StaticArray` with the given *args*. The type of the
  # static array will be the union of the type of the given *args*,
  # and its size will be the number of elements in *args*.
  #
  # ```
  # ary = StaticArray[1, 'a']
  # ary[0]    # => 1
  # ary[1]    # => 'a'
  # ary.class # => StaticArray(Char | Int32, 2)
  # ```
  #
  # See also: `Number.static_array`.
  macro [](*args)
    %array = uninitialized StaticArray(typeof({{*args}}), {{args.size}})
    {% for arg, i in args %}
      %array.to_unsafe[{{i}}] = {{arg}}
    {% end %}
    %array
  end

  # Creates a new static array and invokes the
  # block once for each index of the array, assigning the
  # block's value in that index.
  #
  # ```
  # StaticArray(Int32, 3).new { |i| i * 2 } # => StaticArray[0, 2, 4]
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
  # StaticArray(Int32, 3).new(42) # => StaticArray[42, 42, 42]
  # ```
  def self.new(value : T)
    new { value }
  end

  # Disallow creating an uninitialized StaticArray with new.
  # If this is desired, one can use `array = uninitialized ...`
  # which makes it clear that it's unsafe.
  private def initialize
  end

  # Equality. Returns `true` if each element in `self` is equal to each
  # corresponding element in *other*.
  #
  # ```
  # array = StaticArray(Int32, 3).new 0  # => StaticArray[0, 0, 0]
  # array2 = StaticArray(Int32, 3).new 0 # => StaticArray[0, 0, 0]
  # array3 = StaticArray(Int32, 3).new 1 # => StaticArray[1, 1, 1]
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

  # Equality with another object. Always returns `false`.
  #
  # ```
  # array = StaticArray(Int32, 3).new 0 # => StaticArray[0, 0, 0]
  # array == nil                        # => false
  # ```
  def ==(other)
    false
  end

  @[AlwaysInline]
  def unsafe_at(index : Int)
    to_unsafe[index]
  end

  # Sets the given value at the given *index*.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 } # => StaticArray[1, 2, 3]
  # array[2] = 2                                    # => 2
  # array                                           # => StaticArray[1, 2, 2]
  # array[4] = 4                                    # raises IndexError
  # ```
  @[AlwaysInline]
  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    to_unsafe[index] = value
  end

  # Yields the current element at the given index and updates the value
  # at the given *index* with the block's value.
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 } # => StaticArray[1, 2, 3]
  # array.update(1) { |x| x * 2 }                   # => 4
  # array                                           # => StaticArray[1, 4, 3]
  # array.update(5) { |x| x * 2 }                   # raises IndexError
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

  # Fills the array by substituting all elements with the given value.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.[]= 2 # => nil
  # array       # => StaticArray[2, 2, 2]
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
  # a = StaticArray(Int32, 3).new { |i| i + 1 } # => StaticArray[1, 2, 3]
  # a.shuffle!(Random.new(42))                  # => StaticArray[3, 2, 1]
  # a                                           # => StaticArray[3, 2, 1]
  # ```
  def shuffle!(random = Random::DEFAULT)
    to_slice.shuffle!(random)
    self
  end

  # Invokes the given block for each element of `self`, replacing the element
  # with the value returned by the block. Returns `self`.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.map! { |x| x*x } # => StaticArray[1, 4, 9]
  # ```
  def map!
    to_unsafe.map!(size) { |e| yield e }
    self
  end

  # Returns a new static array where elements are mapped by the given block.
  #
  # ```
  # array = StaticArray[1, 2.5, "a"]
  # tuple.map &.to_s # => StaticArray["1", "2.5", "a"]
  # ```
  def map(&block : T -> U) forall U
    StaticArray(U, N).new { |i| yield to_unsafe[i] }
  end

  # Like `map!`, but the block gets passed both the element and its index.
  def map_with_index!(&block : (T, Int32) -> T)
    to_unsafe.map_with_index!(size) { |e, i| yield e, i }
    self
  end

  # Like `map`, but the block gets passed both the element and its index.
  def map_with_index(&block : (T, Int32) -> U) forall U
    StaticArray(U, N).new { |i| yield to_unsafe[i], i }
  end

  # Reverses the elements of this array in-place, then returns `self`.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.reverse! # => StaticArray[3, 2, 1]
  # ```
  def reverse!
    to_slice.reverse!
    self
  end

  # Returns a slice that points to the elements of this static array.
  # Changes made to the returned slice also affect this static array.
  #
  # ```
  # array = StaticArray(Int32, 3).new(2)
  # slice = array.to_slice # => Slice[2, 2, 2]
  # slice[0] = 3
  # array # => StaticArray[3, 2, 2]
  # ```
  def to_slice
    Slice.new(to_unsafe, size)
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

  # Appends a string representation of this static array to the given `IO`.
  #
  # ```
  # array = StaticArray(Int32, 3).new { |i| i + 1 }
  # array.to_s # => "StaticArray[1, 2, 3]"
  # ```
  def to_s(io : IO)
    io << "StaticArray["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def pretty_print(pp)
    # Don't pass `self` here because we'll pass `self` by
    # value and for big static arrays that seems to make
    # LLVM really slow.
    # TODO: investigate why, maybe report a bug to LLVM?
    pp.list("StaticArray[", to_slice, "]")
  end

  # Returns a new `StaticArray` where each element is cloned from elements in `self`.
  def clone
    array = uninitialized self
    N.times do |i|
      array.to_unsafe[i] = to_unsafe[i].clone
    end
    array
  end

  # :nodoc:
  def index(object, offset : Int = 0)
    # Optimize for the case of looking for a byte in a byte slice
    if T.is_a?(UInt8.class) &&
       (object.is_a?(UInt8) || (object.is_a?(Int) && 0 <= object < 256))
      return to_slice.fast_index(object, offset)
    end

    super
  end
end
