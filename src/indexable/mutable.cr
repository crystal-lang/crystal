# An `Indexable` container that is additionally mutable.
#
# Including types may write values to numeric indices, apart from reading them.
# This module does not cover cases where the container is resized.
module Indexable::Mutable(T)
  include Indexable(T)

  # Sets the element at the given *index* to *value*, without doing any bounds
  # check.
  #
  # `Indexable::Mutable` makes sure to invoke this method with *index* in
  # `0...size`, so converting negative indices to positive ones is not needed
  # here.
  #
  # Clients never invoke this method directly. Instead, they modify elements
  # with `#[]=(index, value)`.
  #
  # This method should only be directly invoked if you are absolutely
  # sure the index is in bounds, to avoid a bounds check for a small boost
  # of performance.
  abstract def unsafe_put(index : Int, value : T)

  # Sets the given *value* at the given *index*. Returns *value*.
  #
  # Negative indices can be used to start counting from the end of the
  # container. Raises `IndexError` if trying to set an element outside the
  # container's range.
  #
  # ```
  # ary = [1, 2, 3]
  # ary[0] = 5
  # ary # => [5, 2, 3]
  #
  # ary[3] = 5 # raises IndexError
  # ```
  @[AlwaysInline]
  def []=(index : Int, value : T) : T
    index = check_index_out_of_bounds index
    unsafe_put(index, value)
    value
  end

  # Yields the current element at the given *index* and updates the value
  # at that *index* with the block's value. Returns the new value.
  #
  # Raises `IndexError` if trying to set an element outside the container's
  # range.
  #
  # ```
  # array = [1, 2, 3]
  # array.update(1) { |x| x * 2 } # => 4
  # array                         # => [1, 4, 3]
  # array.update(5) { |x| x * 2 } # raises IndexError
  # ```
  def update(index : Int, & : T -> _) : T
    index = check_index_out_of_bounds index
    value = yield unsafe_fetch(index)
    unsafe_put(index, value)
    value
  end

  # Swaps the elements at *index0* and *index1*. Returns `self`.
  #
  # Negative indices can be used to start counting from the end of the
  # container. Raises `IndexError` if either index is out of bounds.
  #
  # ```
  # a = ["first", "second", "third"]
  # a.swap(1, 2)  # => ["first", "third", "second"]
  # a             # => ["first", "third", "second"]
  # a.swap(0, -1) # => ["second", "third", "first"]
  # a             # => ["second", "third", "first"]
  # a.swap(2, 3)  # raises IndexError
  # ```
  def swap(index0 : Int, index1 : Int) : self
    index0 = check_index_out_of_bounds(index0)
    index1 = check_index_out_of_bounds(index1)

    unless index0 == index1
      tmp = unsafe_fetch(index0)
      unsafe_put(index0, unsafe_fetch(index1))
      unsafe_put(index1, tmp)
    end

    self
  end

  # Reverses in-place all the elements of `self`. Returns `self`.
  def reverse! : self
    return self if size <= 1

    index0 = 0
    index1 = size - 1

    while index0 < index1
      swap(index0, index1)
      index0 += 1
      index1 -= 1
    end

    self
  end

  # Replaces every element in `self` with the given *value*. Returns `self`.
  #
  # ```
  # array = [1, 2, 3, 4]
  # array.fill(2) # => [2, 2, 2, 2]
  # array         # => [2, 2, 2, 2]
  # ```
  def fill(value : T) : self
    each_index do |i|
      unsafe_put(i, value)
    end
    self
  end

  # Replaces *count* or less (if there aren't enough) elements starting at the
  # given *start* index with *value*. Returns `self`.
  #
  # Negative values of *start* count from the end of the container.
  #
  # Raises `IndexError` if the *start* index is out of range.
  #
  # Raises `ArgumentError` if *count* is negative.
  #
  # ```
  # array = [1, 2, 3, 4, 5]
  # array.fill(9, 2, 2) # => [1, 2, 9, 9, 5]
  # array               # => [1, 2, 9, 9, 5]
  # ```
  def fill(value : T, start : Int, count : Int) : self
    return self if count <= 0
    start, count = normalize_start_and_count(start, count)
    count.times do |i|
      unsafe_put(start + i, value)
    end
    self
  end

  # Replaces the elements within the given *range* with *value*. Returns `self`.
  #
  # Negative indices count backward from the end of the container.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # array = [1, 2, 3, 4, 5]
  # array.fill(9, 2..3) # => [1, 2, 9, 9, 5]
  # array               # => [1, 2, 9, 9, 5]
  # ```
  def fill(value : T, range : Range) : self
    fill(value, *Indexable.range_to_index_and_count(range, size) || raise IndexError.new)
  end

  # Yields each index of `self` to the given block and then assigns
  # the block's value in that position. Returns `self`.
  #
  # Accepts an optional *offset* parameter, which tells the block to start
  # counting from there.
  #
  # ```
  # array = [2, 1, 1, 1]
  # array.fill { |i| i * i }            # => [0, 1, 4, 9]
  # array                               # => [0, 1, 4, 9]
  # array.fill(offset: 3) { |i| i * i } # => [9, 16, 25, 36]
  # array                               # => [9, 16, 25, 36]
  # ```
  def fill(*, offset : Int = 0, & : Int32 -> T) : self
    each_index do |i|
      unsafe_put(i, yield offset + i)
    end
    self
  end

  # Yields each index of `self`, starting at *start* and for *count* times (or
  # less if there aren't enough elements), to the given block and then assigns
  # the block's value in that position. Returns `self`.
  #
  # Negative values of *start* count from the end of the container.
  #
  # Has no effect if *count* is zero or negative.
  #
  # Raises `IndexError` if *start* is outside the array range.
  #
  # ```
  # a = [1, 2, 3, 4, 5, 6]
  # a.fill(2, 3) { |i| i * i * i } # => [1, 2, 8, 27, 64, 6]
  # ```
  def fill(start : Int, count : Int, & : Int32 -> T) : self
    return self if count <= 0
    start, count = normalize_start_and_count(start, count)
    count.times do |i|
      unsafe_put(start + i, yield start + i)
    end
    self
  end

  # Yields each index of `self`, in the given *range*, to the given block and
  # then assigns the block's value in that position. Returns `self`.
  #
  # Negative indices count backward from the end of the container.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # a = [1, 2, 3, 4, 5, 6]
  # a.fill(2..4) { |i| i * i * i } # => [1, 2, 8, 27, 64, 6]
  # ```
  def fill(range : Range, & : Int32 -> T) : self
    fill(*Indexable.range_to_index_and_count(range, size) || raise IndexError.new) do |i|
      yield i
    end
  end

  {% begin %}
  # Invokes the given block for each element of `self`, replacing the element
  # with the value returned by the block. Returns `self`.
  #
  # ```
  # a = [1, 2, 3]
  # a.map! { |x| x * x }
  # a # => [1, 4, 9]
  # ```
  {% if compare_versions(Crystal::VERSION, "1.1.1") >= 0 %}
  def map!(& : T -> _) : self # TODO: add as constant
  {% else %}
  def map!(&) # it doesn't compile with the type annotation in the 1.0.0 compiler
  {% end %}
    each_index do |i|
      unsafe_put(i, yield unsafe_fetch(i))
    end
    self
  end
  {% end %}

  # Like `#map!`, but the block gets passed both the element and its index.
  #
  # Accepts an optional *offset* parameter, which tells it to start counting
  # from there.
  #
  # ```
  # gems = ["crystal", "pearl", "diamond"]
  # gems.map_with_index! { |gem, i| "#{i}: #{gem}" }
  # gems # => ["0: crystal", "1: pearl", "2: diamond"]
  # ```
  def map_with_index!(offset = 0, & : T, Int32 -> _) : self
    each_index do |i|
      unsafe_put(i, yield(unsafe_fetch(i), offset + i))
    end
    self
  end

  # Modifies `self` by randomizing the order of elements in the collection
  # using the given *random* number generator. Returns `self`.
  #
  # ```
  # a = [1, 2, 3, 4, 5]
  # a.shuffle!(Random.new(42)) # => [3, 2, 4, 5, 1]
  # a                          # => [3, 2, 4, 5, 1]
  # ```
  def shuffle!(random : Random = Random::DEFAULT) : self
    (size - 1).downto(1) do |i|
      j = random.rand(i + 1)
      swap(i, j)
    end
    self
  end

  # Shifts all elements of `self` to the left *n* times. Returns `self`.
  #
  # ```
  # a1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  # a2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  # a3 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  #
  # a1.rotate!
  # a2.rotate!(1)
  # a3.rotate!(3)
  #
  # a1 # => [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
  # a2 # => [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
  # a3 # => [3, 4, 5, 6, 7, 8, 9, 0, 1, 2]
  # ```
  def rotate!(n : Int = 1) : self
    return self if size <= 1
    n %= size
    return self if n == 0

    # juggling algorithm
    size.gcd(n).times do |i|
      tmp = unsafe_fetch(i)
      j = i

      while true
        k = j + n
        k -= size if k >= size
        break if k == i
        unsafe_put(j, unsafe_fetch(k))
        j = k
      end

      unsafe_put(j, tmp)
    end

    self
  end

  # Sorts all elements in `self` based on the return value of the comparison
  # method `T#<=>` (see `Comparable#<=>`), using a stable sort algorithm.
  #
  # ```
  # a = [3, 1, 2]
  # a.sort!
  # a # => [1, 2, 3]
  # ```
  #
  # This sort operation modifies `self`. See `#sort` for a non-modifying option
  # that allocates a new instance.
  #
  # See `Slice#sort!` for details on the implementation.
  #
  # Raises `ArgumentError` if the comparison between any two elements returns `nil`.
  def sort! : self
    slice = Slice.new(size) { |i| unsafe_fetch(i) }.sort!
    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i))
    end
    self
  end

  # Sorts all elements in `self` based on the return value of the comparison
  # method `T#<=>` (see `Comparable#<=>`), using an unstable sort algorithm.
  #
  # ```
  # a = [3, 1, 2]
  # a.unstable_sort!
  # a # => [1, 2, 3]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort` for a non-modifying
  # option that allocates a new instance.
  #
  # See `Slice#unstable_sort!` for details on the implementation.
  #
  # Raises `ArgumentError` if the comparison between any two elements returns `nil`.
  def unstable_sort! : self
    slice = Slice.new(size) { |i| unsafe_fetch(i) }.unstable_sort!
    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i))
    end
    self
  end

  # Sorts all elements in `self` based on the comparator in the given block, using
  # a stable sort algorithm.
  #
  # The block must implement a comparison between two elements *a* and *b*,
  # where `a < b` returns `-1`, `a == b` returns `0`, and `a > b` returns `1`.
  # The comparison operator `<=>` can be used for this.
  #
  # ```
  # a = [3, 1, 2]
  # # This is a reverse sort (forward sort would be `a <=> b`)
  # a.sort! { |a, b| b <=> a }
  # a # => [3, 2, 1]
  # ```
  #
  # This sort operation modifies `self`. See `#sort(&block : T, T -> U)` for a
  # non-modifying option that allocates a new instance.
  #
  # See `Slice#sort!(&block : T, T -> U)` for details on the implementation.
  #
  # Raises `ArgumentError` if for any two elements the block returns `nil`.
  def sort!(&block : T, T -> U) : self forall U
    {% unless U <= Int32? %}
      {% raise "Expected block to return Int32 or Nil, not #{U}" %}
    {% end %}

    slice = Slice.new(size) { |i| unsafe_fetch(i) }.sort!(&block)
    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i))
    end
    self
  end

  # Sorts all elements in `self` based on the comparator in the given block,
  # using an unstable sort algorithm.
  #
  # The block must implement a comparison between two elements *a* and *b*,
  # where `a < b` returns `-1`, `a == b` returns `0`, and `a > b` returns `1`.
  # The comparison operator `<=>` can be used for this.
  #
  # ```
  # a = [3, 1, 2]
  # # This is a reverse sort (forward sort would be `a <=> b`)
  # a.unstable_sort! { |a, b| b <=> a }
  # a # => [3, 2, 1]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort(&block : T, T -> U)`
  # for a non-modifying option that allocates a new instance.
  #
  # See `Slice#unstable_sort!(&block : T, T -> U)` for details on the implementation.
  #
  # Raises `ArgumentError` if for any two elements the block returns `nil`.
  def unstable_sort!(&block : T, T -> U) : self forall U
    {% unless U <= Int32? %}
      {% raise "Expected block to return Int32 or Nil, not #{U}" %}
    {% end %}

    slice = Slice.new(size) { |i| unsafe_fetch(i) }.unstable_sort!(&block)
    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i))
    end
    self
  end

  # Sorts all elements in `self` by the output value of the
  # block. The output values are compared via the comparison method `#<=>`
  # (see `Comparable#<=>`), using a stable sort algorithm.
  #
  # ```
  # a = %w(apple pear fig)
  # a.sort_by! { |word| word.size }
  # a # => ["fig", "pear", "apple"]
  # ```
  #
  # This sort operation modifies `self`. See `#sort_by(&block : T -> _)` for a
  # non-modifying option that allocates a new instance.
  #
  # If stability is expendable, `#unstable_sort_by!(&block : T -> _)` provides a
  # performance advantage over stable sort.
  #
  # See `#sort!(&block : T -> _)` for details on the sorting mechanism.
  #
  # Raises `ArgumentError` if the comparison between any two comparison values returns `nil`.
  def sort_by!(&block : T -> _) : self
    slice = Slice.new(size) do |i|
      elem = unsafe_fetch(i)
      {elem, (yield elem)}
    end.sort! { |x, y| x[1] <=> y[1] }

    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i)[0])
    end
    self
  end

  # Sorts all elements in `self` by the output value of the
  # block. The output values are compared via the comparison method `#<=>`
  # (see `Comparable#<=>`), using an unstable sort algorithm.
  #
  # ```
  # a = %w(apple pear fig)
  # a.unstable_sort_by! { |word| word.size }
  # a # => ["fig", "pear", "apple"]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort_by(&block : T -> _)`
  # for a non-modifying option that allocates a new instance.
  #
  # If stability is necessary, use  `#sort_by!(&block : T -> _)` instead.
  #
  # See `#unstable_sort!(&block : T -> _)` for details on the sorting mechanism.
  #
  # Raises `ArgumentError` if the comparison between any two comparison values returns `nil`.
  def unstable_sort_by!(&block : T -> _) : self
    slice = Slice.new(size) do |i|
      elem = unsafe_fetch(i)
      {elem, (yield elem)}
    end.unstable_sort! { |x, y| x[1] <=> y[1] }

    each_index do |i|
      unsafe_put(i, slice.unsafe_fetch(i)[0])
    end
    self
  end
end
