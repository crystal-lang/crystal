# An Array is an ordered, integer-indexed collection of objects of type T.
#
# Array indexing starts at 0. A negative index is assumed to be
# relative to the end of the array: -1 indicates the last element,
# -2 is the next to last element, and so on.
#
# An Array can be created using the usual `new` method (several are provided), or with an array literal:
#
# ```
# Array(Int32).new  # => []
# [1, 2, 3]         # Array(Int32)
# [1, "hello", 'x'] # Array(Int32 | String | Char)
# ```
#
# An Array can have mixed types, meaning T will be a union of types, but these are determined
# when the array is created, either by specifying T or by using an array literal. In the latter
# case, T will be set to the union of the array literal elements' types.
#
# When creating an empty array you must always specify T:
#
# ```
# [] of Int32 # same as Array(Int32)
# []          # syntax error
# ```
#
# An Array is implemented using an internal buffer of some capacity
# that is reallocated when elements are pushed to it and more capacity
# is needed. This is normally known as a [dynamic array](http://en.wikipedia.org/wiki/Dynamic_array).
#
# You can use a special array literal syntax with other types too, as long as they define an argless
# `new` method and a `<<` method. `Set` is one such type:
#
# ```
# set = Set{1, 2, 3} # => [1, 2, 3]
# set.class          # => Set(Int32)
# ```
#
# The above is the same as this:
#
# ```
# set = Set(typeof(1, 2, 3)).new
# set << 1
# set << 2
# set << 3
# ```
class Array(T)
  include Enumerable(T)
  include Iterable
  include Comparable(Array)

  # Returns the number of elements in the array.
  #
  # ```
  # [:foo, :bar].size # => 2
  # ```
  getter size
  @size :: Int32
  @capacity :: Int32

  # Creates a new empty Array.
  def initialize
    @size = 0
    @capacity = 0
    @buffer = Pointer(T).null
  end

  # Creates a new empty Array backed by a buffer that is initially
  # `initial_capacity` big.
  #
  # The `initial_capacity` is useful to avoid unnecessary reallocations
  # of the internal buffer in case of growth. If you have an estimate
  # of the maxinum number of elements an array will hold, you should
  # initialize it with that capacity for improved execution performance.
  #
  #
  # ```
  # ary = Array(Int32).new(5)
  # ary.size # => 0
  # ```
  def initialize(initial_capacity : Int)
    if initial_capacity < 0
      raise ArgumentError.new("negative array size: #{initial_capacity}")
    end

    @size = 0
    @capacity = initial_capacity.to_i
    if initial_capacity == 0
      @buffer = Pointer(T).null
    else
      @buffer = Pointer(T).malloc(initial_capacity)
    end
  end

  # Creates a new Array of the given size filled with the
  # same value in each position.
  #
  # ```
  # Array.new(3, 'a') # => ['a', 'a', 'a']
  #
  # ary = Array.new(3, [1])
  # puts ary # => [[1], [1], [1]]
  # ary[0][0] = 2
  # puts ary # => [[2], [2], [2]]
  # ```
  def initialize(size : Int, value : T)
    if size < 0
      raise ArgumentError.new("negative array size: #{size}")
    end

    @size = size.to_i
    @capacity = size.to_i

    if size == 0
      @buffer = Pointer(T).null
    else
      @buffer = Pointer(T).malloc(size, value)
    end
  end

  # Creates a new Array of the given size and invokes the
  # block once for each index of the array, assigning the
  # block's value in that index.
  #
  # ```
  # Array.new(3) { |i| (i + 1) ** 2 } # => [1, 4, 9]
  #
  # ary = Array.new(3) { [1] }
  # puts ary # => [[1], [1], [1]]
  # ary[0][0] = 2
  # puts ary # => [[2], [1], [1]]
  # ```
  def self.new(size : Int, &block : Int32 -> T)
    Array(T).build(size) do |buffer|
      size.times do |i|
        buffer[i] = yield i
      end
      size
    end
  end

  # Creates a new Array, allocating an internal buffer with the given capacity,
  # and yielding that buffer. The block must return the desired size of the array.
  #
  # This method is **unsafe**, but is usually used to initialize the buffer
  # by passing it to a C function.
  #
  # ```
  # Array.build(3) do |buffer|
  #   LibSome.fill_buffer_and_return_number_of_elements_filled(buffer)
  # end
  # ```
  def self.build(capacity : Int)
    ary = Array(T).new(capacity)
    ary.size = (yield ary.buffer).to_i
    ary
  end

  # Equality. Returns true if it is passed an Array and `equals?`
  # returns true for both arrays, the caller and the argument.
  #
  # ```
  # ary = [1, 2, 3]
  # ary == [1, 2, 3] # => true
  # ary == [2, 3]    # => false
  # ```
  def ==(other : Array)
    equals?(other) { |x, y| x == y }
  end

  # :nodoc:
  def ==(other)
    false
  end

  # Combined comparison operator. Returns 0 if the first array equals the second, 1
  # if the first is greater than the second and -1 if the first is smaller than
  # the second.
  #
  # It compares the elements of both arrays in the same position using the
  # `<=>` operator, as soon as one of such comparisons returns a non zero
  # value, that result is the return value of the whole comparison.
  #
  # If all elements are equal, the comparison is based on the size of the arrays.
  #
  # ```
  # [8] <=> [1, 2, 3] # => 1
  # [2] <=> [4, 2, 3] # => -1
  # [1, 2] <=> [1, 2] # => 0
  # ```
  def <=>(other : Array)
    min_size = Math.min(size, other.size)
    0.upto(min_size - 1) do |i|
      n = buffer[i] <=> other.buffer[i]
      return n if n != 0
    end
    size <=> other.size
  end

  # Set intersection: returns a new array containing elements common to the two
  # arrays, excluding any duplicates. The order is preserved from the original
  # array.
  #
  # ```
  # [1, 1, 3, 5] & [1, 2, 3]               # => [ 1, 3 ]
  # ['a', 'b', 'b', 'z'] & ['a', 'b', 'c'] # => [ 'a', 'b' ]
  # ```
  #
  # See also: `#uniq`.
  def &(other : Array(U))
    return Array(T).new if self.empty? || other.empty?

    hash = other.to_lookup_hash
    hash_size = hash.size
    Array(T).build(Math.min(size, other.size)) do |buffer|
      i = 0
      each do |obj|
        hash.delete(obj)
        new_hash_size = hash.size
        if hash_size != new_hash_size
          hash_size = new_hash_size
          buffer[i] = obj
          i += 1
        end
      end
      i
    end
  end

  # Set union: returns a new array by joining ary with `other_ary`, excluding
  # any duplicates and preserving the order from the original array.
  #
  # ```
  # ["a", "b", "c"] | ["c", "d", "a"] # => [ "a", "b", "c", "d" ]
  # ```
  #
  # See also: `#uniq`.
  def |(other_ary : Array(U))
    Array(T | U).build(size + other_ary.size) do |buffer|
      hash = Hash(T, Bool).new
      i = 0
      each do |obj|
        unless hash.has_key?(obj)
          buffer[i] = obj
          hash[obj] = true
          i += 1
        end
      end
      other_ary.each do |obj|
        unless hash.has_key?(obj)
          buffer[i] = obj
          hash[obj] = true
          i += 1
        end
      end
      i
    end
  end

  # Concatenation. Returns a new array built by concatenating two arrays
  # together to create a third. The type of the new array is the union of the
  # types of both the other arrays.
  #
  # ```
  # [1, 2] + ["a"]  # => [1,2,"a"] of (Int32 | String)
  # [1, 2] + [2, 3] # => [1,2,2,3]
  # ```
  def +(other : Array(U))
    new_size = size + other.size
    Array(T | U).build(new_size) do |buffer|
      buffer.copy_from(self.buffer, size)
      (buffer + size).copy_from(other.buffer, other.size)
      new_size
    end
  end

  # Difference. Returns a new array that is a copy of the original, removing
  # any items that appear in `other`. The order of the original array is
  # preserved.
  #
  # ```
  # [1, 2, 3] - [2, 1] # => [3]
  # ```
  def -(other : Array(U))
    ary = Array(T).new(Math.max(size - other.size, 0))
    hash = other.to_lookup_hash
    each do |obj|
      ary << obj unless hash.has_key?(obj)
    end
    ary
  end

  # Repetition: Returns a new array built by concatenating `times` copies of `ary`.
  #
  # ```
  # ["a", "b", "c"] * 2 # => [ "a", "b", "c", "a", "b", "c" ]
  # ```
  def *(times : Int)
    ary = Array(T).new(size * times)
    times.times do
      ary.concat(self)
    end
    ary
  end

  # Append. Alias for `push`.
  #
  # ```
  # a = [1, 2]
  # a << 3 # => [1,2,3]
  # ```
  def <<(value : T)
    push(value)
  end

  # Returns the element at the given index.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to access an element outside the array's range.
  #
  # ```
  # ary = ['a', 'b', 'c']
  # ary[0]  # => 'a'
  # ary[2]  # => 'c'
  # ary[-1] # => 'c'
  # ary[-2] # => 'b'
  #
  # ary[3]  # raises IndexError
  # ary[-4] # raises IndexError
  # ```
  @[AlwaysInline]
  def [](index : Int)
    at(index)
  end

  # Returns the element at the given index.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Returns `nil` if trying to access an element outside the array's range.
  #
  # ```
  # ary = ['a', 'b', 'c']
  # ary[0]?  # => 'a'
  # ary[2]?  # => 'c'
  # ary[-1]? # => 'c'
  # ary[-2]? # => 'b'
  #
  # ary[3]?  # nil
  # ary[-4]? # nil
  # ```
  @[AlwaysInline]
  def []?(index : Int)
    at(index) { nil }
  end

  # Sets the given value at the given index.
  #
  # Negative indices can be used to start counting from the end of the array.
  # Raises `IndexError` if trying to set an element outside the array's range.
  #
  # ```
  # ary = [1, 2, 3]
  # ary[0] = 5
  # p ary # => [5,2,3]
  #
  # ary[3] = 5 # => IndexError
  # ```
  @[AlwaysInline]
  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    @buffer[index] = value
  end

  # Replaces a subrange with a single value. All elements in the range
  # `index...index+count` are removed and replaced by a single element
  # *value*.
  #
  # If *count* is zero, *value* is inserted at *index*.
  #
  # Negative values of *index* count from the end of the array.
  #
  # ```
  # a = [1, 2, 3, 4, 5]
  # a[1, 3] = 6
  # a # => [1, 6, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1, 0] = 6
  # a # => [1, 6, 2, 3, 4, 5]
  # ```
  def []=(index : Int, count : Int, value : T)
    raise ArgumentError.new "negative count: #{count}" if count < 0

    index = check_index_out_of_bounds index
    count = index + count <= size ? count : size - index

    case count
    when 0
      insert index, value
    when 1
      @buffer[index] = value
    else
      diff = count - 1
      (@buffer + index + 1).move_from(@buffer + index + count, size - index - count)
      (@buffer + @size - diff).clear(diff)
      @buffer[index] = value
      @size -= diff
    end

    value
  end

  # Replaces a subrange with a single value.
  #
  # ```
  # a = [1, 2, 3, 4, 5]
  # a[1..3] = 6
  # a # => [1, 6, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1...1] = 6
  # a # => [1, 6, 2, 3, 4, 5]
  # ```
  def []=(range : Range(Int, Int), value : T)
    self[*range_to_index_and_count(range)] = value
  end

  # Replaces a subrange with the elements of the given array.
  #
  # ```
  # a = [1, 2, 3, 4, 5]
  # a[1, 3] = [6, 7, 8]
  # a # => [1, 6, 7, 8, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1, 3] = [6, 7]
  # a # => [1, 6, 7, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1, 3] = [6, 7, 8, 9, 10]
  # a # => [1, 6, 7, 8, 9, 10, 5]
  # ```
  def []=(index : Int, count : Int, values : Array(T))
    raise ArgumentError.new "negative count: #{count}" if count < 0

    index = check_index_out_of_bounds index
    count = index + count <= size ? count : size - index
    diff = values.size - count

    if diff == 0
      # Replace values directly
      (@buffer + index).copy_from(values.to_unsafe, values.size)
    elsif diff < 0
      # Need to shrink
      diff = -diff
      (@buffer + index).copy_from(values.to_unsafe, values.size)
      (@buffer + index + values.size).move_from(@buffer + index + count, size - index - count)
      (@buffer + @size - diff).clear(diff)
      @size -= diff
    else
      # Need to grow
      resize_to_capacity(Math.pw2ceil(@size + diff))
      (@buffer + index + values.size).move_from(@buffer + index + count, size - index - count)
      (@buffer + index).copy_from(values.to_unsafe, values.size)
      @size += diff
    end

    values
  end

  # Replaces a subrange with the elements of the given array.
  #
  # ```
  # a = [1, 2, 3, 4, 5]
  # a[1..3] = [6, 7, 8]
  # a # => [1, 6, 7, 8, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1..3] = [6, 7]
  # a # => [1, 6, 7, 5]
  #
  # a = [1, 2, 3, 4, 5]
  # a[1..3] = [6, 7, 8, 9, 10]
  # a # => [1, 6, 7, 8, 9, 10, 5]
  # ```
  def []=(range : Range(Int, Int), values : Array(T))
    self[*range_to_index_and_count(range)] = values
  end

  # Returns all elements that are within the given range
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element). Aditionally, an empty array is returned when the starting index
  # for an element range is at the end of the array.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # a = ["a", "b", "c", "d", "e"]
  # a[1..3]    # => ["b", "c", "d"]
  # a[4..7]    # => ["e"]
  # a[6..10]   # => Index Error
  # a[5..10]   # => []
  # a[-2...-1] # => ["d"]
  # ```
  def [](range : Range(Int, Int))
    self[*range_to_index_and_count(range)]
  end

  # Returns count or less (if there aren't enough) elements starting at the
  # given start index.
  #
  # Negative indices count backward from the end of the array (-1 is the last
  # element). Aditionally, an empty array is returned when the starting index
  # for an element range is at the end of the array.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # a = ["a", "b", "c", "d", "e"]
  # a[-3, 3] # => ["c", "d", "e"]
  # a[6, 1]  # => Index Error
  # a[1, 2]  # => ["b", "c"]
  # a[5, 1]  # => []
  # ```
  def [](start : Int, count : Int)
    raise ArgumentError.new "negative count: #{count}" if count < 0

    if start == size
      return Array(T).new
    end

    start += size if start < 0
    raise IndexError.new unless 0 <= start <= size

    if count == 0
      return Array(T).new
    end

    count = Math.min(count, size - start)

    Array(T).build(count) do |buffer|
      buffer.copy_from(@buffer + start, count)
      count
    end
  end

  # Returns the element at the given index, if in bounds,
  # otherwise raises `IndexError`.
  #
  # ```
  # a = [:foo, :bar]
  # a.at(0) # => :foo
  # a.at(2) # => IndexError
  # ```
  @[AlwaysInline]
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  # Returns the element at the given index, if in bounds,
  # otherwise executes the given block and returns its value.
  #
  # ```
  # a = [:foo, :bar]
  # a.at(0) { :baz } # => :foo
  # a.at(2) { :baz } # => :baz
  # ```
  def at(index : Int)
    index += size if index < 0
    if 0 <= index < size
      @buffer[index]
    else
      yield
    end
  end

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # ["a", "b", "c", "d"].values_at(0, 2) # => {"a", "c"}
  # ```
  def values_at(*indexes : Int)
    indexes.map { |index| self[index] }
  end

  # :nodoc:
  def buffer
    @buffer
  end

  # Removes all elements from self.
  #
  # ```
  # a = ["a", "b", "c", "d", "e"]
  # a.clear # => []
  # ```
  def clear
    @buffer.clear(@size)
    @size = 0
    self
  end

  # Returns a new Array that has this array's elements cloned.
  # That is, it returns a deep copy of this array.
  #
  # Use `#dup` if you want a shallow copy.
  #
  # ```
  # ary = [[1, 2], [3, 4]]
  # ary2 = ary.clone
  # ary[0][0] = 5
  # puts ary  # => [[5, 2], [3, 4]]
  # puts ary2 # => [[1, 2], [3, 4]]
  #
  # ary2 << [7, 8]
  # puts ary  # => [[5, 2], [3, 4]]
  # puts ary2 # => [[1, 2], [3, 4], [7, 8]]
  # ```
  def clone
    Array(T).new(size) { |i| @buffer[i].clone as T }
  end

  # Returns a copy of self with all nil elements removed.
  #
  # ```
  # ["a", nil, "b", nil, "c", nil].compact # => ["a", "b", "c"]
  # ```
  def compact
    compact_map &.itself
  end

  # Removes nil elements from this array.
  #
  # ```
  # ary = ["a", nil, "b", nil, "c"]
  # ary.compact!
  # ary # => ["a", "b", "c"]
  # ```
  def compact!
    delete nil
  end

  # Appends the elements of *other* to `self`, and returns `self`.
  #
  # ```
  # ary = ["a", "b"]
  # ary.concat(["c", "d"])
  # ary # => ["a", "b", "c", "d"]
  # ```
  def concat(other : Array)
    other_size = other.size
    new_size = size + other_size
    if new_size > @capacity
      resize_to_capacity(Math.pw2ceil(new_size))
    end

    (@buffer + @size).copy_from(other.buffer, other_size)
    @size += other_size

    self
  end

  # ditto
  def concat(other : Enumerable)
    left_before_resize = @capacity - @size
    len = @size
    buf = @buffer + len
    other.each do |elem|
      if left_before_resize == 0
        left_before_resize = @capacity
        resize_to_capacity(@capacity * 2)
        buf = @buffer + len
      end
      buf.value = elem
      buf += 1
      len += 1
      left_before_resize -= 1
    end

    @size = len

    self
  end

  # Deletes all items from `self` that are equal to `obj`.
  #
  # ```
  # a = ["a", "b", "b", "b", "c"]
  # a.delete("b")
  # a # => ["a", "c"]
  # ```
  def delete(obj)
    reject! { |e| e == obj } != nil
  end

  # Deletes the element at the given index, returning that element.
  # Raises `IndexError` if the index is out of range.
  #
  # ```
  # a = ["ant", "bat", "cat", "dog"]
  # a.delete_at(2)  # => "cat"
  # a               # => ["ant", "bat", "dog"]
  # a.delete_at(99) # => IndexError
  # ```
  def delete_at(index : Int)
    index = check_index_out_of_bounds index

    elem = @buffer[index]
    (@buffer + index).move_from(@buffer + index + 1, size - index - 1)
    @size -= 1
    (@buffer + @size).clear
    elem
  end

  # Deletes all elements that are within the given range,
  # returning that elements.
  # Raises `IndexError` if the index is out of range.
  #
  # ```
  # a = ["ant", "bat", "cat", "dog"]
  # a.delete_at(1..2)    # => ["bat", "cat"]
  # a                    # => ["ant", "dog"]
  # a.delete_at(99..100) # => IndexError
  # ```
  def delete_at(range : Range(Int, Int))
    from, size = range_to_index_and_count(range)
    delete_at(from, size)
  end

  # Deletes count or less (if there aren't enough) elements at the given start index,
  # returning that elements.
  # Raises `IndexError` if the index is out of range.
  #
  # ```
  # a = ["ant", "bat", "cat", "dog"]
  # a.delete_at(1, 2)  # => ["bat", "cat"]
  # a                  # => ["ant", "dog"]
  # a.delete_at(99, 1) # => IndexError
  # ```
  def delete_at(index : Int, count : Int)
    val = self[index, count]
    count = index + count <= size ? count : size - index
    (@buffer + index).move_from(@buffer + index + count, size - index - count)
    @size -= count
    (@buffer + @size).clear(count)
    val
  end

  # Returns a new Array that has exactly this array's elements.
  # That is, it returns a shallow copy of this array.
  #
  # Use `#clone` if you want a deep copy.
  #
  # ```
  # ary = [[1, 2], [3, 4]]
  # ary2 = ary.dup
  # ary[0][0] = 5
  # puts ary  # => [[5, 2], [3, 4]]
  # puts ary2 # => [[5, 2], [3, 4]]
  #
  # ary2 << [7, 8]
  # puts ary  # => [[5, 2], [3, 4]]
  # puts ary2 # => [[5, 2], [3, 4], [7, 8]]
  # ```
  def dup
    Array(T).build(@capacity) do |buffer|
      buffer.copy_from(self.buffer, size)
      size
    end
  end

  def each
    each_index do |i|
      yield @buffer[i]
    end
  end

  def each
    ItemIterator.new(self)
  end

  def each_index
    i = 0
    while i < size
      yield i
      i += 1
    end
    self
  end

  def each_index
    IndexIterator.new(self)
  end

  def empty?
    @size == 0
  end

  def equals?(other : Array)
    return false if @size != other.size
    each_with_index do |item, i|
      return false unless yield(item, other[i])
    end
    true
  end

  def fill
    each_index { |i| @buffer[i] = yield i }

    self
  end

  def fill(from : Int)
    from += size if from < 0

    raise IndexError.new if from >= size

    from.upto(size - 1) { |i| @buffer[i] = yield i }

    self
  end

  def fill(from : Int, count : Int)
    return self if count < 0

    from += size if from < 0
    count += size if count < 0

    raise IndexError.new if from >= size || count + from > size

    count += from - 1

    from.upto(count) { |i| @buffer[i] = yield i }

    self
  end

  def fill(range : Range(Int, Int))
    fill(*range_to_index_and_count(range)) do |i|
      yield i
    end
  end

  def fill(value : T)
    fill { value }
  end

  def fill(value : T, from : Int)
    fill(from) { value }
  end

  def fill(value : T, from : Int, size : Int)
    fill(from, size) { value }
  end

  def fill(value : T, range : Range(Int, Int))
    fill(range) { value }
  end

  def first
    first { raise IndexError.new }
  end

  def first
    @size == 0 ? yield : @buffer[0]
  end

  def first?
    first { nil }
  end

  def hash
    inject(31 * @size) do |memo, elem|
      31 * memo + elem.hash
    end
  end

  def insert(index : Int, obj : T)
    check_needs_resize

    if index < 0
      index += size + 1
    end

    unless 0 <= index <= size
      raise IndexError.new
    end

    (@buffer + index + 1).move_from(@buffer + index, size - index)
    @buffer[index] = obj
    @size += 1
    self
  end

  def inspect(io : IO)
    to_s io
  end

  def last
    last { raise IndexError.new }
  end

  def last
    @size == 0 ? yield : @buffer[@size - 1]
  end

  def last?
    last { nil }
  end

  # :nodoc:
  protected def size=(size : Int)
    @size = size.to_i
  end

  def map(&block : T -> U)
    Array(U).new(size) { |i| yield buffer[i] }
  end

  def map!
    @buffer.map!(size) { |e| yield e }
    self
  end

  # Equivalent to `Array#select` but makes modification on the current object rather that returning a new one. Returns nil if no changes were made
  def select!
    reject! { |elem| !yield(elem) }
  end

  # Equivalent to `Array#reject`, but makes modification on the current object rather that returning a new one. Returns nil if no changes were made.
  def reject!
    i1 = 0
    i2 = 0
    while i1 < @size
      e = @buffer[i1]
      unless yield e
        if i1 != i2
          @buffer[i2] = e
        end
        i2 += 1
      end

      i1 += 1
    end

    if i2 != i1
      count = i1 - i2
      @size -= count
      (@buffer + @size).clear(count)
      self
    else
      nil
    end
  end

  def map_with_index(&block : T, Int32 -> U)
    Array(U).new(size) { |i| yield buffer[i], i }
  end

  # Returns an `Array` with all possible permutations of the given *size*.
  #
  #     a = [1, 2, 3]
  #     a.permutations    #=> [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
  #     a.permutations(1) #=> [[1],[2],[3]]
  #     a.permutations(2) #=> [[1,2],[1,3],[2,1],[2,3],[3,1],[3,2]]
  #     a.permutations(3) #=> [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
  #     a.permutations(0) #=> [[]]
  #     a.permutations(4) #=> []
  #
  def permutations(size = self.size : Int)
    ary = [] of Array(T)
    each_permutation(size) do |a|
      ary << a
    end
    ary
  end

  # Yields each possible permutation of size `n` of this array.
  #
  #     a = [1, 2, 3]
  #     sums = [] of Int32
  #     a.each_permutation(2) { |p| sums << p.sum } #=> [1, 2, 3]
  #     sums #=> [3, 4, 3, 5, 4, 5]
  #
  def each_permutation(size = self.size : Int)
    n = self.size
    return self if size > n

    raise ArgumentError.new("size must be positive") if size < 0

    pool = self.dup
    cycles = (n - size + 1..n).to_a.reverse!
    yield pool[0, size]

    while true
      stop = true
      i = size - 1
      while i >= 0
        ci = (cycles[i] -= 1)
        if ci == 0
          e = pool[i]
          (i + 1).upto(n - 1) { |j| pool[j - 1] = pool[j] }
          pool[n - 1] = e
          cycles[i] = n - i
        else
          pool.swap i, -ci
          yield pool[0, size]
          stop = false
          break
        end
        i -= 1
      end

      return self if stop
    end
  end

  def combinations(size = self.size : Int)
    ary = [] of Array(T)
    each_combination(size) do |a|
      ary << a
    end
    ary
  end

  def each_combination(size = self.size : Int)
    n = self.size
    return self if size > n
    raise ArgumentError.new("size must be positive") if size < 0

    copy = self.dup
    pool = self.dup

    indices = (0...size).to_a
    yield pool[0, size]

    while true
      stop = true
      i = size - 1
      while i >= 0
        if indices[i] != i + n - size
          stop = false
          break
        end
        i -= 1
      end

      return self if stop

      indices[i] += 1
      pool[i] = copy[indices[i]]

      (i + 1).upto(size - 1) do |j|
        indices[j] = indices[j - 1] + 1
        pool[j] = copy[indices[j]]
      end

      yield pool[0, size]
    end
  end

  # Returns a new array that is a one-dimensional flattening of self (recursively).
  #
  # That is, for every element that is an array, extract its elements into the new array
  #
  # ```
  # s = [1, 2, 3]         # => [1, 2, 3]
  # t = [4, 5, 6, [7, 8]] # => [4, 5, 6, [7, 8]]
  # a = [s, t, 9, 10]     # => [[1, 2, 3], [4, 5, 6, [7, 8]], 9, 10]
  # a.flatten             # => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  # ```
  def flatten
    FlattenHelper(typeof(FlattenHelper.element_type(self))).flatten(self)
  end

  def repeated_combinations(size = self.size : Int)
    ary = [] of Array(T)
    each_repeated_combination(size) do |a|
      ary << a
    end
    ary
  end

  def each_repeated_combination(size = self.size : Int)
    n = self.size
    return self if size > n && n == 0
    raise ArgumentError.new("size must be positive") if size < 0

    copy = self.dup
    indices = Array.new(size, 0)
    pool = indices.map { |i| copy[i] }

    yield pool[0, size]

    while true
      stop = true

      i = size - 1
      while i >= 0
        if indices[i] != n - 1
          stop = false
          break
        end
        i -= 1
      end
      return self if stop

      ii = indices[i] + 1
      tmp = copy[ii]
      indices.fill(i, size - i) { ii }
      pool.fill(i, size - i) { tmp }

      yield pool[0, size]
    end
  end

  def self.product(arrays)
    result = [] of Array(typeof(arrays.first.first))
    each_product(arrays) do |product|
      result << product
    end
    result
  end

  def self.product(*arrays : Array)
    product(arrays.to_a)
  end

  def self.each_product(arrays)
    pool = arrays.map &.first
    lens = arrays.map &.size
    return if lens.any? &.==(0)
    n = arrays.size
    indices = Array.new(n, 0)
    yield pool[0, n]

    while true
      i = n - 1
      indices[i] += 1

      while indices[i] >= lens[i]
        indices[i] = 0
        pool[i] = arrays[i][indices[i]]
        i -= 1
        return if i < 0
        indices[i] += 1
      end
      pool[i] = arrays[i][indices[i]]
      yield pool[0, n]
    end
  end

  def self.each_product(*arrays : Array)
    each_product(arrays.to_a) do |result|
      yield result
    end
  end

  def repeated_permutations(size = self.size : Int)
    ary = [] of Array(T)
    each_repeated_permutation(size) do |a|
      ary << a
    end
    ary
  end

  def each_repeated_permutation(size = self.size : Int)
    n = self.size
    return self if size != 0 && n == 0
    raise ArgumentError.new("size must be positive") if size < 0

    if size == 0
      yield([] of T)
    else
      Array.each_product(Array.new(size, self)) { |r| yield r }
    end

    self
  end

  def pop
    pop { raise IndexError.new }
  end

  def pop
    if @size == 0
      yield
    else
      @size -= 1
      value = @buffer[@size]
      (@buffer + @size).clear
      value
    end
  end

  def pop(n : Int)
    if n < 0
      raise ArgumentError.new("can't pop negative count")
    end

    n = Math.min(n, @size)
    ary = Array(T).new(n) { |i| @buffer[@size - n + i] }

    @size -= n
    (@buffer + @size).clear(n)

    ary
  end

  def pop?
    pop { nil }
  end

  def product(ary : Array(U))
    result = Array({T, U}).new(size * ary.size)
    product(ary) do |x, y|
      result << {x, y}
    end
    result
  end

  def product(ary, &block)
    self.each { |a| ary.each { |b| yield a, b } }
  end

  # Append. Pushes one value to the end of the array, given that the type of
  # the value is T (which might be a type or a union of types). This expression
  # returns the array iself, so several of them can be chained. See `pop` for
  # the opposite effect.
  #
  # ```
  # a = ["a", "b"]
  # a.push("c") # => ["a", "b", "c"]
  # a.push(1)   # => Errors, because the array only accepts String
  #
  # a = ["a", "b"] of (Int32 | String)
  # a.push("c") # => ["a", "b", "c"]
  # a.push(1)   # => ["a", "b", "c", 1]
  # ```
  def push(value : T)
    check_needs_resize
    @buffer[@size] = value
    @size += 1
    self
  end

  # Append multiple values. The same as `push`, but takes an arbitrary number
  # of values to push into the array.
  def push(*values : T)
    values.each do |value|
      self << value
    end
  end

  def replace(other : Array)
    @size = other.size
    resize_to_capacity(Math.pw2ceil(@size)) if @size > @capacity
    @buffer.copy_from(other.buffer, other.size)
    self
  end

  def reverse
    Array(T).new(size) { |i| @buffer[size - i - 1] }
  end

  def reverse!
    i = 0
    j = size - 1
    while i < j
      @buffer.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def reverse_each
    (size - 1).downto(0) do |i|
      yield @buffer[i]
    end
    self
  end

  def reverse_each
    ReverseIterator.new(self)
  end

  def rindex(value)
    rindex { |elem| elem == value }
  end

  def rindex
    (size - 1).downto(0) do |i|
      if yield @buffer[i]
        return i
      end
    end
    nil
  end

  def rotate!(n = 1)
    return self if size == 0
    n %= size if n.abs >= size
    n += size if n < 0
    return self if n == 0
    if n <= size / 2
      tmp = self[0..n]
      @buffer.move_from(@buffer + n, size - n)
      (@buffer + size - n).copy_from(tmp.buffer, n)
    else
      tmp = self[n..-1]
      (@buffer + size - n).move_from(@buffer, n)
      @buffer.copy_from(tmp.buffer, size - n)
    end
    self
  end

  def rotate(n = 1)
    return self if size == 0
    n %= size if n.abs >= size
    n += size if n < 0
    return self if n == 0
    res = Array(T).new(size)
    res.buffer.copy_from(@buffer + n, size - n)
    (res.buffer + size - n).copy_from(@buffer, n)
    res.size = size
    res
  end

  def sample
    raise IndexError.new if @size == 0
    @buffer[rand(@size)]
  end

  def sample(n)
    if n < 0
      raise ArgumentError.new("can't get negative count sample")
    end

    case n
    when 0
      return [] of T
    when 1
      return [sample] of T
    else
      if n >= @size
        return dup.shuffle!
      end

      ary = Array(T).new(n) { |i| @buffer[i] }
      buffer = ary.buffer

      n.upto(@size - 1) do |i|
        j = rand(i + 1)
        if j <= n
          buffer[j] = @buffer[i]
        end
      end
      ary.shuffle!

      ary
    end
  end

  def shift
    shift { raise IndexError.new }
  end

  def shift
    if @size == 0
      yield
    else
      value = @buffer[0]
      @size -= 1
      @buffer.move_from(@buffer + 1, @size)
      (@buffer + @size).clear
      value
    end
  end

  def shift(n : Int)
    if n < 0
      raise ArgumentError.new("can't shift negative count")
    end

    n = Math.min(n, @size)
    ary = Array(T).new(n) { |i| @buffer[i] }

    @buffer.move_from(@buffer + n, @size - n)
    @size -= n
    (@buffer + @size).clear(n)

    ary
  end

  def shift?
    shift { nil }
  end

  def shuffle
    dup.shuffle!
  end

  def shuffle!
    @buffer.shuffle!(size)
    self
  end

  def sort
    dup.sort!
  end

  def sort(&block : T, T -> Int32)
    dup.sort! &block
  end

  def sort!
    Array.quicksort!(@buffer, @size)
    self
  end

  def sort!(&block : T, T -> Int32)
    Array.quicksort!(@buffer, @size, block)
    self
  end

  def sort_by(&block : T -> _)
    dup.sort_by! &block
  end

  def sort_by!(&block : T -> _)
    sort! { |x, y| block.call(x) <=> block.call(y) }
  end

  def swap(index0, index1)
    index0 += size if index0 < 0
    index1 += size if index1 < 0

    unless (0 <= index0 < size) && (0 <= index1 < size)
      raise IndexError.new
    end

    @buffer[index0], @buffer[index1] = @buffer[index1], @buffer[index0]

    self
  end

  def to_a
    self
  end

  def to_s(io : IO)
    executed = exec_recursive(:to_s) do
      io << "["
      join ", ", io, &.inspect(io)
      io << "]"
    end
    io << "[...]" unless executed
  end

  def to_unsafe
    @buffer
  end

  # Assumes that `self` is an array of array and transposes the rows and columns.
  #
  # ```
  # a = [[:a, :b], [:c, :d], [:e, :f]]
  # a.transpose # => [[:a, :c, :e], [:b, :d, :f]]
  # a           # => [[:a, :b], [:c, :d], [:e, :f]]
  # ```
  def transpose
    return Array(Array(typeof(first.first))).new if empty?

    len = at(0).size
    (1...@size).each do |i|
      l = at(i).size
      raise IndexError.new if len != l
    end

    Array(Array(typeof(first.first))).new(len) do |i|
      Array(typeof(first.first)).new(@size) do |j|
        at(j).at(i)
      end
    end
  end

  # Returns a new array by removing duplicate values in `self`.
  #
  # ```
  # a = ["a", "a", "b", "b", "c"]
  # a.uniq # => ["a", "b", "c"]
  # a      # => [ "a", "a", "b", "b", "c" ]
  # ```
  def uniq
    uniq &.itself
  end

  # Returns a new array by removing duplicate values in `self`, using the block's
  # value for comparison.
  #
  # ```
  # a = [{"student", "sam"}, {"student", "george"}, {"teacher", "matz"}]
  # a.uniq { |s| s[0] } # => [{"student", "sam"}, {"teacher", "matz"}]
  # a                   # => [{"student", "sam"}, {"student", "george"}, {"teacher", "matz"}]
  # ```
  def uniq(&block : T -> _)
    if size <= 1
      dup
    else
      hash = to_lookup_hash { |elem| yield elem }
      hash.values
    end
  end

  # Removes duplicate elements from `self`. Returns `self`.
  #
  # ```
  # a = ["a", "a", "b", "b", "c"]
  # a.uniq! # => ["a", "b", "c"]
  # a       # => ["a", "b", "c"]
  # ```
  def uniq!
    uniq! &.itself
  end

  # Removes duplicate elements from `self`, using the block's value for comparison. Returns `self`.
  #
  # ```
  # a = [{"student", "sam"}, {"student", "george"}, {"teacher", "matz"}]
  # a.uniq! { |s| s[0] } # => [{"student", "sam"}, {"teacher", "matz"}]
  # a                    # => [{"student", "sam"}, {"teacher", "matz"}]
  # ```
  def uniq!
    if size <= 1
      return self
    end

    hash = to_lookup_hash { |elem| yield elem }
    if size == hash.size
      return self
    end

    old_size = @size
    @size = hash.size
    removed = old_size - @size
    return self if removed == 0

    ptr = @buffer
    hash.each do |k, v|
      ptr.value = v
      ptr += 1
    end

    (@buffer + @size).clear(removed)

    self
  end

  def unshift(obj : T)
    insert 0, obj
  end

  def update(index : Int)
    index = check_index_out_of_bounds index
    buffer[index] = yield buffer[index]
  end

  def zip(other : Array)
    each_with_index do |elem, i|
      yield elem, other[i]
    end
  end

  def zip(other : Array(U))
    pairs = Array({T, U}).new(size)
    zip(other) { |x, y| pairs << {x, y} }
    pairs
  end

  def zip?(other : Array)
    each_with_index do |elem, i|
      yield elem, other[i]?
    end
  end

  def zip?(other : Array(U))
    pairs = Array({T, U?}).new(size)
    zip?(other) { |x, y| pairs << {x, y} }
    pairs
  end

  private def check_needs_resize
    resize_to_capacity(@capacity == 0 ? 3 : (@capacity * 2)) if @size == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    if @buffer
      @buffer = @buffer.realloc(@capacity)
    else
      @buffer = Pointer(T).malloc(@capacity)
    end
  end

  protected def self.quicksort!(a, n, comp)
    return if (n < 2)
    p = a[n / 2]
    l = a
    r = a + n - 1
    while l <= r
      if comp.call(l.value, p) < 0
        l += 1
      elsif comp.call(r.value, p) > 0
        r -= 1
      else
        t = l.value
        l.value = r.value
        l += 1
        r.value = t
        r -= 1
      end
    end
    quicksort!(a, (r - a) + 1, comp) unless r == a + n - 1
    quicksort!(l, (a + n) - l, comp) unless l == a
  end

  protected def self.quicksort!(a, n)
    return if (n < 2)
    p = a[n / 2]
    l = a
    r = a + n - 1
    while l <= r
      if l.value < p
        l += 1
      elsif r.value > p
        r -= 1
      else
        t = l.value
        l.value = r.value
        l += 1
        r.value = t
        r -= 1
      end
    end
    quicksort!(a, (r - a) + 1) unless r == a + n - 1
    quicksort!(l, (a + n) - l) unless l == a
  end

  private def check_index_out_of_bounds(index)
    index += size if index < 0
    unless 0 <= index < size
      raise IndexError.new
    end
    index
  end

  protected def to_lookup_hash
    to_lookup_hash { |elem| elem }
  end

  protected def to_lookup_hash(&block : T -> U)
    each_with_object(Hash(U, T).new) do |o, h|
      key = yield o
      unless h.has_key?(key)
        h[key] = o
      end
    end
  end

  private def range_to_index_and_count(range)
    from = range.begin
    from += size if from < 0
    raise IndexError.new if from < 0

    to = range.end
    to += size if to < 0
    to -= 1 if range.excludes_end?
    size = to - from + 1
    size = 0 if size < 0

    {from, size}
  end

  # :nodoc:
  class ItemIterator(T)
    include Iterator(T)

    def initialize(@array : Array(T), @index = 0)
    end

    def next
      value = @array.at(@index) { stop }
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end

  # :nodoc:
  class IndexIterator(T)
    include Iterator(Int32)

    def initialize(@array : Array(T), @index = 0)
    end

    def next
      return stop if @index >= @array.size

      value = @index
      @index += 1
      value
    end

    def rewind
      @index = 0
      self
    end
  end

  # :nodoc:
  class ReverseIterator(T)
    include Iterator(T)

    def initialize(@array : Array(T), @index = array.size - 1)
    end

    def next
      return stop if @index < 0

      value = @array.at(@index) { stop }
      @index -= 1
      value
    end

    def rewind
      @index = @array.size - 1
      self
    end
  end

  # :nodoc:
  struct FlattenHelper(T)
    def self.flatten(ary)
      result = [] of T
      flatten ary, result
      result
    end

    def self.flatten(ary : Array, result)
      ary.each do |elem|
        flatten elem, result
      end
    end

    def self.flatten(other : T, result)
      result << other
    end

    def self.element_type(ary)
      if ary.is_a?(Array)
        element_type(ary.first)
      else
        ary
      end
    end
  end
end
