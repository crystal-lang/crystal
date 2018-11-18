# A container that allows accessing elements via a numeric index.
#
# Indexing starts at `0`. A negative index is assumed to be
# relative to the end of the container: `-1` indicates the last element,
# `-2` is the next to last element, and so on.
#
# Types including this module are typically `Array`-like types.
module Indexable(T)
  include Iterable(T)
  include Enumerable(T)

  # Returns the number of elements in this container.
  abstract def size

  # Returns the element at the given *index*, without doing any bounds check.
  #
  # `Indexable` makes sure to invoke this method with *index* in `0...size`,
  # so converting negative indices to positive ones is not needed here.
  #
  # Clients never invoke this method directly. Instead, they access
  # elements with `#[](index)` and `#[]?(index)`.
  #
  # This method should only be directly invoked if you are absolutely
  # sure the index is in bounds, to avoid a bounds check for a small boost
  # of performance.
  abstract def unsafe_fetch(index : Int)

  # Returns the element at the given *index*, if in bounds,
  # otherwise executes the given block with the index and returns its value.
  #
  # ```
  # a = [:foo, :bar]
  # a.fetch(0) { :default_value }    # => :foo
  # a.fetch(2) { :default_value }    # => :default_value
  # a.fetch(2) { |index| index * 3 } # => 6
  # ```
  def fetch(index : Int)
    index = check_index_out_of_bounds(index) do
      return yield index
    end
    unsafe_fetch(index)
  end

  # Returns the value at the index given by *index*, or when not found the value given by *default*.
  #
  # ```
  # a = [:foo, :bar]
  # a.fetch(0, :default_value) # => :foo
  # a.fetch(2, :default_value) # => :default_value
  # ```
  @[AlwaysInline]
  def fetch(index, default)
    fetch(index) { default }
  end

  # Returns the element at the given *index*.
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
    fetch(index) { raise IndexError.new }
  end

  # Returns the element at the given *index*.
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
    fetch(index, nil)
  end

  # Traverses the depth of a structure and returns the value.
  # Returns `nil` if not found.
  #
  # ```
  # ary = [{1, 2, 3, {4, 5, 6}}]
  # ary.dig?(0, 3, 2) # => 6
  # ary.dig?(0, 3, 3) # => nil
  # ```
  def dig?(index : Int, *subindexes)
    if (value = self[index]?) && value.responds_to?(:dig?)
      value.dig?(*subindexes)
    end
  end

  # :nodoc:
  def dig?(index : Int)
    self[index]?
  end

  # Traverses the depth of a structure and returns the value, otherwise
  # raises `IndexError`.
  #
  # ```
  # ary = [{1, 2, 3, {4, 5, 6}}]
  # ary.dig(0, 3, 2) # => 6
  # ary.dig(0, 3, 3) # raises IndexError
  # ```
  def dig(index : Int, *subindexes)
    if (value = self[index]) && value.responds_to?(:dig)
      return value.dig(*subindexes)
    end
    raise IndexError.new "Indexable value not diggable for index: #{index.inspect}"
  end

  # :nodoc:
  def dig(index : Int)
    self[index]
  end

  # By using binary search, returns the first element
  # for which the passed block returns `true`.
  #
  # If the block returns `false`, the finding element exists
  # behind. If the block returns `true`, the finding element
  # is itself or exists infront.
  #
  # Binary search needs sorted array, so `self` has to be sorted.
  #
  # Returns `nil` if the block didn't return `true` for any element.
  #
  # ```
  # [2, 5, 7, 10].bsearch { |x| x >= 4 } # => 5
  # [2, 5, 7, 10].bsearch { |x| x > 10 } # => nil
  # ```
  def bsearch
    bsearch_index { |value| yield value }.try { |index| unsafe_fetch(index) }
  end

  # By using binary search, returns the index of the first element
  # for which the passed block returns `true`.
  #
  # If the block returns `false`, the finding element exists
  # behind. If the block returns `true`, the finding element
  # is itself or exists infront.
  #
  # Binary search needs sorted array, so `self` has to be sorted.
  #
  # Returns `nil` if the block didn't return `true` for any element.
  #
  # ```
  # [2, 5, 7, 10].bsearch_index { |x, i| x >= 4 } # => 1
  # [2, 5, 7, 10].bsearch_index { |x, i| x > 10 } # => nil
  # ```
  def bsearch_index
    (0...size).bsearch { |index| yield unsafe_fetch(index), index }
  end

  # Calls the given block once for each element in `self`, passing that
  # element as a parameter.
  #
  # ```
  # a = ["a", "b", "c"]
  # a.each { |x| print x, " -- " }
  # ```
  #
  # produces:
  #
  # ```text
  # a -- b -- c --
  # ```
  def each
    each_index do |i|
      yield unsafe_fetch(i)
    end
  end

  # Returns an `Iterator` for the elements of `self`.
  #
  # ```
  # a = ["a", "b", "c"]
  # iter = a.each
  # iter.next # => "a"
  # iter.next # => "b"
  # ```
  #
  # The returned iterator keeps a reference to `self`: if the array
  # changes, the returned values of the iterator change as well.
  def each
    ItemIterator(self, T).new(self)
  end

  # Calls the given block once for `count` number of elements in `self`
  # starting from index `start`, passing each element as a parameter.
  #
  # Negative indices count backward from the end of the array. (-1 is the
  # last element).
  #
  # Raises `IndexError` if the starting index is out of range.
  # Raises `ArgumentError` if `count` is a negative number.
  #
  # ```
  # array = ["a", "b", "c", "d", "e"]
  # array.each(start: 1, count: 3) { |x| print x, " -- " }
  # ```
  #
  # produces:
  #
  # ```text
  # b -- c -- d --
  # ```
  def each(*, start : Int, count : Int)
    each_index(start: start, count: count) do |i|
      yield unsafe_fetch(i)
    end
  end

  # Calls the given block once for all elements at indices within the given
  # `range`, passing each element as a parameter.
  #
  # Raises `IndexError` if the starting index is out of range.
  #
  # ```
  # array = ["a", "b", "c", "d", "e"]
  # array.each(within: 1..3) { |x| print x, " -- " }
  # ```
  #
  # produces:
  #
  # ```text
  # b -- c -- d --
  # ```
  def each(*, within range : Range(Int, Int))
    start, count = Indexable.range_to_index_and_count(range, size)
    each(start: start, count: count) { |element| yield element }
  end

  # Calls the given block once for each index in `self`, passing that
  # index as a parameter.
  #
  # ```
  # a = ["a", "b", "c"]
  # a.each_index { |x| print x, " -- " }
  # ```
  #
  # produces:
  #
  # ```text
  # 0 -- 1 -- 2 --
  # ```
  def each_index : Nil
    i = 0
    while i < size
      yield i
      i += 1
    end
  end

  # Returns an `Iterator` for each index in `self`.
  #
  # ```
  # a = ["a", "b", "c"]
  # iter = a.each_index
  # iter.next # => 0
  # iter.next # => 1
  # ```
  #
  # The returned iterator keeps a reference to `self`. If the array
  # changes, the returned values of the iterator will change as well.
  def each_index
    IndexIterator.new(self)
  end

  # Calls the given block once for `count` number of indices in `self`
  # starting from index `start`, passing each index as a parameter.
  #
  # Negative indices count backward from the end of the array. (-1 is the
  # last element).
  #
  # Raises `IndexError` if the starting index is out of range.
  # Raises `ArgumentError` if `count` is a negative number.
  #
  # ```
  # array = ["a", "b", "c", "d", "e"]
  # array.each_index(start: -3, count: 2) { |x| print x, " -- " }
  # ```
  #
  # produces:
  #
  # ```text
  # 2 -- 3 --
  # ```
  def each_index(*, start : Int, count : Int)
    raise ArgumentError.new "negative count: #{count}" if count < 0

    start += size if start < 0
    raise IndexError.new unless 0 <= start <= size

    i = start
    # `count` and size comparison must be done every iteration because
    # `self` can mutate in the block.
    while i < Math.min(start + count, size)
      yield i
      i += 1
    end
    self
  end

  # Optimized version of `Enumerable#join` that performs better when
  # all of the elements in this indexable are strings: the total string
  # bytesize to return can be computed before creating the final string,
  # which performs better because there's no need to do reallocations.
  def join(separator = "")
    return "" if empty?

    {% if T == String %}
      join_strings(separator)
    {% elsif String < T %}
      if all?(&.is_a?(String))
        join_strings(separator)
      else
        super(separator)
      end
    {% else %}
      super(separator)
    {% end %}
  end

  private def join_strings(separator)
    separator = separator.to_s

    # The total bytesize of the string to return is:
    length =
      ((self.size - 1) * separator.bytesize) + # the bytesize of all separators
        self.sum(&.to_s.bytesize)              # the bytesize of all the elements

    String.new(length) do |buffer|
      # Also compute the UTF-8 size if we can
      size = 0
      size_known = true

      each_with_index do |elem, i|
        # elem is guaranteed to be a String, but the compiler doesn't know this
        # if we enter via the all?(&.is_a?(String)) branch.
        elem = elem.to_s

        # Copy separator to buffer
        if i != 0
          buffer.copy_from(separator.to_unsafe, separator.bytesize)
          buffer += separator.bytesize
        end

        # Copy element to buffer
        buffer.copy_from(elem.to_unsafe, elem.bytesize)
        buffer += elem.bytesize

        # Check whether we'll know the final UTF-8 size
        if elem.size_known?
          size += elem.size
        else
          size_known = false
        end
      end

      # Add size of all separators
      size += (self.size - 1) * separator.size if size_known

      {length, size_known ? size : 0}
    end
  end

  # Returns an `Array` with all the elements in the collection.
  #
  # ```
  # {1, 2, 3}.to_a # => [1, 2, 3]
  # ```
  def to_a
    ary = Array(T).new(size)
    each { |e| ary << e }
    ary
  end

  # Returns `true` if `self` is empty, `false` otherwise.
  #
  # ```
  # ([] of Int32).empty? # => true
  # ([1]).empty?         # => false
  # ```
  def empty?
    size == 0
  end

  # Optimized version of `equals?` used when `other` is also an `Indexable`.
  def equals?(other : Indexable)
    return false if size != other.size
    each_with_index do |item, i|
      return false unless yield(item, other.unsafe_fetch(i))
    end
    true
  end

  # Determines if `self` equals *other* according to a comparison
  # done by the given block.
  #
  # If `self`'s size is the same as *other*'s size, this method yields
  # elements from `self` and *other* in tandem: if the block returns true
  # for all of them, this method returns `true`. Otherwise it returns `false`.
  #
  # ```
  # a = [1, 2, 3]
  # b = ["a", "ab", "abc"]
  # a.equals?(b) { |x, y| x == y.size } # => true
  # a.equals?(b) { |x, y| x == y }      # => false
  # ```
  def equals?(other)
    return false if size != other.size
    each_with_index do |item, i|
      return false unless yield(item, other[i])
    end
    true
  end

  # Returns the first element of `self` if it's not empty, or raises `IndexError`.
  #
  # ```
  # ([1, 2, 3]).first   # => 1
  # ([] of Int32).first # raises IndexError
  # ```
  def first
    first { raise IndexError.new }
  end

  # Returns the first element of `self` if it's not empty, or the given block's value.
  #
  # ```
  # ([1, 2, 3]).first { 4 }   # => 1
  # ([] of Int32).first { 4 } # => 4
  # ```
  def first
    size == 0 ? yield : unsafe_fetch(0)
  end

  # Returns the first element of `self` if it's not empty, or `nil`.
  #
  # ```
  # ([1, 2, 3]).first?   # => 1
  # ([] of Int32).first? # => nil
  # ```
  def first?
    first { nil }
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher = size.hash(hasher)
    each do |elem|
      hasher = elem.hash(hasher)
    end
    hasher
  end

  # Returns the index of the first appearance of *value* in `self`
  # starting from the given *offset*, or `nil` if the value is not in `self`.
  #
  # ```
  # [1, 2, 3, 1, 2, 3].index(2, offset: 2) # => 4
  # ```
  def index(object, offset : Int = 0)
    index(offset) { |e| e == object }
  end

  # Returns the index of the first object in `self` for which the block
  # returns `true`, starting from the given *offset*, or `nil` if no match
  # is found.
  #
  # ```
  # [1, 2, 3, 1, 2, 3].index(offset: 2) { |x| x < 2 } # => 3
  # ```
  def index(offset : Int = 0)
    offset += size if offset < 0
    return nil if offset < 0

    offset.upto(size - 1) do |i|
      if yield unsafe_fetch(i)
        return i
      end
    end
    nil
  end

  # Returns the last element of `self` if it's not empty, or raises `IndexError`.
  #
  # ```
  # ([1, 2, 3]).last   # => 3
  # ([] of Int32).last # raises IndexError
  # ```
  def last
    last { raise IndexError.new }
  end

  # Returns the last element of `self` if it's not empty, or the given block's value.
  #
  # ```
  # ([1, 2, 3]).last { 4 }   # => 3
  # ([] of Int32).last { 4 } # => 4
  # ```
  def last
    size == 0 ? yield : unsafe_fetch(size - 1)
  end

  # Returns the last element of `self` if it's not empty, or `nil`.
  #
  # ```
  # ([1, 2, 3]).last?   # => 3
  # ([] of Int32).last? # => nil
  # ```
  def last?
    last { nil }
  end

  # Same as `#each`, but works in reverse.
  def reverse_each(&block) : Nil
    (size - 1).downto(0) do |i|
      yield unsafe_fetch(i)
    end
  end

  # Returns an `Iterator` over the elements of `self` in reverse order.
  def reverse_each
    ReverseItemIterator(self, T).new(self)
  end

  # Returns the index of the last appearance of *value* in `self`, or
  # `nil` if the value is not in `self`.
  #
  # If *offset* is given, it defines the position to _end_ the search
  # (elements beyond this point are ignored).
  #
  # ```
  # [1, 2, 3, 2, 3].rindex(2)            # => 3
  # [1, 2, 3, 2, 3].rindex(2, offset: 2) # => 1
  # ```
  def rindex(value, offset = size - 1)
    rindex(offset) { |elem| elem == value }
  end

  # Returns the index of the first object in `self` for which the block
  # returns `true`, starting from the last object, or `nil` if no match
  # is found.
  #
  # If *offset* is given, the search starts from that index towards the
  # first elements in `self`.
  #
  # ```
  # [1, 2, 3, 2, 3].rindex { |x| x < 3 }            # => 3
  # [1, 2, 3, 2, 3].rindex(offset: 2) { |x| x < 3 } # => 1
  # ```
  def rindex(offset = size - 1)
    offset += size if offset < 0
    return nil if offset >= size

    offset.downto(0) do |i|
      if yield unsafe_fetch(i)
        return i
      end
    end
    nil
  end

  # Returns a random element from `self`, using the given *random* number generator.
  # Raises `IndexError` if `self` is empty.
  #
  # ```
  # a = [1, 2, 3]
  # a.sample                # => 2
  # a.sample                # => 1
  # a.sample(Random.new(1)) # => 3
  # ```
  def sample(random = Random::DEFAULT)
    raise IndexError.new if size == 0
    unsafe_fetch(random.rand(size))
  end

  # Returns a `Tuple` populated with the elements at the given indexes.
  # Raises `IndexError` if any index is invalid.
  #
  # ```
  # ["a", "b", "c", "d"].values_at(0, 2) # => {"a", "c"}
  # ```
  def values_at(*indexes : Int)
    indexes.map { |index| self[index] }
  end

  # Calls the given block for each index in `self`, passing in the elements
  # `{self[i], other[i]}` for each index.
  #
  # Raises an `IndexError` if `other` is shorter than `self`.
  #
  # ```
  # a = [1, 2, 3]
  # b = ["a", "b", "c"]
  #
  # a.zip(b) { |x, y| puts "#{x} -- #{y}" }
  # ```
  #
  # The above produces:
  #
  # ```text
  # 1 --- a
  # 2 --- b
  # 3 --- c
  # ```
  def zip(other : Indexable(U), &block : T, U ->) forall U
    each_with_index do |elem, i|
      yield elem, other[i]
    end
  end

  # Returns an `Array` of tuples populated with the *i*th indexed element from
  # `self` followed by the *i*th indexed element from `other`.
  #
  # Raises an `IndexError` if `other` is shorter than `self`.
  #
  # ```
  # a = [1, 2, 3]
  # b = ["a", "b", "c"]
  #
  # a.zip(b) # => [{1, "a"}, {2, "b"}, {3, "c"}]
  # ```
  def zip(other : Indexable(U)) : Array({T, U}) forall U
    pairs = Array({T, U}).new(size)
    zip(other) { |x, y| pairs << {x, y} }
    pairs
  end

  # Calls the given block for each index in `self`, passing in the elements
  # `{self[i], other[i]}` for each index.
  #
  # If `other` is shorter than `self`, missing values are filled up with `nil`.
  #
  # ```
  # a = [1, 2, 3]
  # b = ["a", "b"]
  #
  # a.zip?(b) { |x, y| puts "#{x} -- #{y}" }
  # ```
  #
  # The above produces:
  #
  # ```text
  # 1 --- a
  # 2 --- b
  # 3 ---
  # ```
  def zip?(other : Indexable(U), &block : T, U? ->) forall U
    each_with_index do |elem, i|
      yield elem, other[i]?
    end
  end

  # Returns an `Array` of tuples populated with the *i*th indexed element from
  # `self` followed by the *i*th indexed element from `other`.
  #
  # If `other` is shorter than `self`, missing values are filled up with `nil`.
  #
  # ```
  # a = [1, 2, 3]
  # b = ["a", "b"]
  #
  # a.zip?(b) # => [{1, "a"}, {2, "b"}, {3, nil}]
  # ```
  def zip?(other : Indexable(U)) : Array({T, U?}) forall U
    pairs = Array({T, U?}).new(size)
    zip?(other) { |x, y| pairs << {x, y} }
    pairs
  end

  private def check_index_out_of_bounds(index)
    check_index_out_of_bounds(index) { raise IndexError.new }
  end

  private def check_index_out_of_bounds(index)
    index += size if index < 0
    if 0 <= index < size
      index
    else
      yield
    end
  end

  # :nodoc:
  def self.range_to_index_and_count(range, collection_size)
    start_index = range.begin
    start_index += collection_size if start_index < 0
    raise IndexError.new if start_index < 0

    end_index = range.end
    end_index += collection_size if end_index < 0
    end_index -= 1 if range.excludes_end?
    count = end_index - start_index + 1
    count = 0 if count < 0

    {start_index, count}
  end

  private class ItemIterator(A, T)
    include Iterator(T)

    def initialize(@array : A, @index = 0)
    end

    def next
      if @index >= @array.size
        stop
      else
        value = @array[@index]
        @index += 1
        value
      end
    end

    def rewind
      @index = 0
      self
    end
  end

  private class ReverseItemIterator(A, T)
    include Iterator(T)

    def initialize(@array : A, @index : Int32 = array.size - 1)
    end

    def next
      if @index < 0
        stop
      else
        value = @array[@index]
        @index -= 1
        value
      end
    end

    def rewind
      @index = @array.size - 1
      self
    end
  end

  private class IndexIterator(A)
    include Iterator(Int32)

    def initialize(@array : A, @index = 0)
    end

    def next
      if @index >= @array.size
        stop
      else
        value = @index
        @index += 1
        value
      end
    end

    def rewind
      @index = 0
      self
    end
  end
end
