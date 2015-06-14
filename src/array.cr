# An Array is an ordered, integer-indexed collection of objects of type T.
#
# Array indexing starts at 0. A negative index is assumed to be
# relative to the end of the array: -1 indicates the last element,
# -2 is the next to last element, and so on.
#
# An Array can be created using the usual `new` method (several are provided), or with an array literal:
#
# ```
# Array(Int32).new  #=> []
# [1, 2, 3]         # Array(Int32)
# [1, "hello", 'x'] # Array(Int32 | String | Char)
# ```
#
# An Array can have mixed types, meaning T will be a union of types, but these are determined
# when the array is created, either by specifying T or by using an array literal. In the later
# case, T will be set to the union of the array literal elements.
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
# set = Set{1, 2, 3} #=> [1, 2, 3]
# set.class          #=> Set(Int32)
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

  getter length
  @length :: Int32
  @capacity :: Int32

  # Creates a new empty Array backed by a buffer that is initially
  # `initial_capacity` big.
  #
  # The `initial_capacity` is useful to avoid unnecesary reallocations
  # of the internal buffer in case of growth. If you have an estimate
  # of the maxinum number of elements an array will hold, you should
  # initialize it with that capacity for improved execution performance.
  #
  #
  # ```
  # ary = Array(Int32).new(5)
  # ary.length #=> 0
  # ```
  def initialize(initial_capacity = 3 : Int)
    initial_capacity = Math.max(initial_capacity, 3)
    @length = 0
    @capacity = initial_capacity.to_i
    @buffer = Pointer(T).malloc(initial_capacity)
  end

  # Creates a new Array of the given size filled with the
  # same value in each position.
  #
  # ```
  # Array.new(3, 'a') #=> ['a', 'a', 'a']
  #
  # ary = Array.new(3, [1])
  # puts ary #=> [[1], [1], [1]]
  # ary[0][0] = 2
  # puts ary #=> [[2], [2], [2]]
  # ```
  def initialize(size, value : T)
    if size < 0
      raise ArgumentError.new("negative array size: #{size}")
    end

    @length = size.to_i
    @capacity = Math.max(size, 3)
    @buffer = Pointer(T).malloc(size, value)
  end

  # Creates a new Array of the given size and invokes the
  # block once for each index of the array, assigning the
  # block's value in that index.
  #
  # ```
  # Array.new(3) { |i| (i + 1) ** 2 } #=> [1, 4, 9]
  #
  # ary = Array.new(3) { [1] }
  # puts ary #=> [[1], [1], [1]]
  # ary[0][0] = 2
  # puts ary #=> [[2], [1], [1]]
  # ```
  def self.new(size, &block : Int32 -> T)
    Array(T).build(size) do |buffer|
      size.times do |i|
        buffer[i] = yield i
      end
      size
    end
  end

  # Creates a new Array, allocating an internal buffer with the given capacity,
  # and yielding that buffer. The block must return the desired length of the array.
  #
  # This method is **unsafe**, but is usually used to initialize the buffer
  # by passing it to a C function.
  #
  # ```
  # Array.new(3) do |buffer|
  #   LibSome.fill_buffer_and_return_number_of_elements_filled(buffer)
  # end
  # ```
  def self.build(capacity : Int)
    ary = Array(T).new(capacity)
    ary.length = (yield ary.buffer).to_i
    ary
  end

  def ==(other : Array)
    equals?(other) { |x, y| x == y }
  end

  def ==(other)
    false
  end

  def <=>(other : Array)
    min_length = Math.min(length, other.length)
    0.upto(min_length - 1) do |i|
      n = buffer[i] <=> other.buffer[i]
      return n if n != 0
    end
    length <=> other.length
  end

  # Set intersection: returns a new array containing elements common to the two arrays, excluding any duplicates.
  # The order is preserved from the original array.
  #
  # ```
  # [ 1, 1, 3, 5 ] & [ 1, 2, 3 ]                 #=> [ 1, 3 ]
  # [ 'a', 'b', 'b', 'z' ] & [ 'a', 'b', 'c' ]   #=> [ 'a', 'b' ]
  # ```
  #
  # See also: `#uniq`.
  def &(other : Array(U))
    return Array(T).new if self.empty? || other.empty?

    hash = other.to_lookup_hash
    hash_length = hash.length
    Array(T).build(Math.min(length, other.length)) do |buffer|
      i = 0
      each do |obj|
        hash.delete(obj)
        new_hash_length = hash.length
        if hash_length != new_hash_length
          hash_length = new_hash_length
          buffer[i] = obj
          i += 1
        end
      end
      i
    end
  end

  # Set union: returns a new array by joining ary with `other_ary`, excluding any duplicates
  # and preserving the order from the original array.
  #
  # ```
  # [ "a", "b", "c" ] | [ "c", "d", "a" ]    #=> [ "a", "b", "c", "d" ]
  # ```
  #
  # See also: `#uniq`.
  def |(other_ary : Array(U))
    Array(T | U).build(length + other_ary.length) do |buffer|
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

  def +(other : Array(U))
    new_length = length + other.length
    Array(T | U).build(new_length) do |buffer|
      buffer.copy_from(self.buffer, length)
      (buffer + length).copy_from(other.buffer, other.length)
      new_length
    end
  end

  def -(other : Array(U))
    ary = Array(T).new(length - other.length)
    hash = other.to_lookup_hash
    each do |obj|
      ary << obj unless hash.has_key?(obj)
    end
    ary
  end

  def <<(value : T)
    push(value)
  end

  def [](index : Int)
    at(index)
  end

  def []?(index : Int)
    at(index) { nil }
  end

  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    @buffer[index] = value
  end

  def [](range : Range)
    from = range.begin
    from += length if from < 0
    to = range.end
    to += length if to < 0
    to -= 1 if range.excludes_end?
    length = to - from + 1
    length = 0 if length < 0
    self[from, length]
  end

  def [](start : Int, count : Int)
    if (start == 0 && length == 0) || (start == length && count >= 0)
      return Array(T).new
    end

    start += length if start < 0
    raise IndexOutOfBounds.new unless 0 <= start <= length
    raise ArgumentError.new "negative count: #{count}" if count < 0

    count = Math.min(count, length - start)

    if count == 0
      return Array(T).new
    end

    Array(T).build(count) do |buffer|
      buffer.copy_from(@buffer + start, count)
      count
    end
  end

  def at(index : Int)
    at(index) { raise IndexOutOfBounds.new }
  end

  def at(index : Int)
    index += length if index < 0
    if index >= length || index < 0
      yield
    else
      @buffer[index]
    end
  end

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # ["a", "b", "c", "d"].values_at(0, 2) #=> {"a", "c"}
  # ```
  def values_at(*indexes : Int)
    indexes.map {|index| self[index] }
  end

  def buffer
    @buffer
  end

  # Removes all elements from self.
  #
  # ```
  # a = [ "a", "b", "c", "d", "e" ]
  # a.clear    #=> []
  # ```
  def clear
    @buffer.clear(@length)
    @length = 0
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
  # puts ary  #=> [[5, 2], [3, 4]]
  # puts ary2 #=> [[1, 2], [3, 4]]
  #
  # ary2 << [7, 8]
  # puts ary  #=> [[5, 2], [3, 4]]
  # puts ary2 #=> [[1, 2], [3, 4], [7, 8]]
  # ```
  def clone
    Array(T).new(length) { |i| @buffer[i].clone as T }
  end

  def compact
    compact_map &.itself
  end

  def compact(array)
    each do |elem|
      array.push elem if elem
    end
  end

  def compact!
    delete nil
  end

  def concat(other : Array)
    other_length = other.length
    new_length = length + other_length
    if new_length > @capacity
      resize_to_capacity(Math.pw2ceil(new_length))
    end

    (@buffer + @length).copy_from(other.buffer, other_length)
    @length += other_length

    self
  end

  def concat(other : Enumerable)
    left_before_resize = @capacity - @length
    len = @length
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

    @length = len

    self
  end

  def count
    @length
  end

  def delete(obj)
    delete_if { |e| e == obj }
  end

  def delete_at(index : Int)
    index = check_index_out_of_bounds index

    elem = @buffer[index]
    (@buffer + index).move_from(@buffer + index + 1, length - index - 1)
    @length -= 1
    (@buffer + @length).clear
    elem
  end

  def delete_if
    i1 = 0
    i2 = 0
    while i1 < @length
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
      @length -= count
      (@buffer + @length).clear(count)
      true
    else
      false
    end
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
  # puts ary  #=> [[5, 2], [3, 4]]
  # puts ary2 #=> [[5, 2], [3, 4]]
  #
  # ary2 << [7, 8]
  # puts ary  #=> [[5, 2], [3, 4]]
  # puts ary2 #=> [[5, 2], [3, 4], [7, 8]]
  # ```
  def dup
    Array(T).build(@capacity) do |buffer|
      buffer.copy_from(self.buffer, length)
      length
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
    while i < length
      yield i
      i += 1
    end
    self
  end

  def each_index
    IndexIterator.new(self)
  end

  def empty?
    @length == 0
  end

  def equals?(other : Array)
    return false if @length != other.length
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
    from += length if from < 0

    raise IndexOutOfBounds.new if from >= length

    from.upto(length - 1) { |i| @buffer[i] = yield i }

    self
  end

  def fill(from : Int, size : Int)
    return self if size < 0

    from += length if from < 0
    size += length if size < 0

    raise IndexOutOfBounds.new if from >= length || size + from > length

    size += from - 1

    from.upto(size) { |i| @buffer[i] = yield i }

    self
  end

  def fill(range : Range(Int, Int))
    from = range.begin
    to = range.end

    from += length if from < 0
    to += length if to < 0

    to -= 1 if range.excludes_end?

    each_index do |i|
      @buffer[i] = yield i if i >= from && i <= to
    end

    self
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
    first { raise IndexOutOfBounds.new }
  end

  def first
    @length == 0 ? yield : @buffer[0]
  end

  def first?
    first { nil }
  end

  def hash
    inject(31 * @length) do |memo, elem|
      31 * memo + elem.hash
    end
  end

  def insert(index : Int, obj : T)
    check_needs_resize

    if index < 0
      index += length + 1
    end

    unless 0 <= index <= length
      raise IndexOutOfBounds.new
    end

    (@buffer + index + 1).move_from(@buffer + index, length - index)
    @buffer[index] = obj
    @length += 1
    self
  end

  def inspect(io : IO)
    to_s io
  end

  def last
    last { raise IndexOutOfBounds.new }
  end

  def last
    @length == 0 ? yield : @buffer[@length - 1]
  end

  def last?
    last { nil }
  end

  def length=(length : Int)
    @length = length.to_i
  end

  def map(&block : T -> U)
    Array(U).new(length) { |i| yield buffer[i] }
  end

  def map!
    @buffer.map!(length) { |e| yield e }
    self
  end

  def select!
    delete_if { |elem| !(yield elem) }
    self
  end

  def reject!
    delete_if { |elem| yield elem }
    self
  end

  def map_with_index(&block : T, Int32 -> U)
    Array(U).new(length) { |i| yield buffer[i], i }
  end

  def pop
    pop { raise IndexOutOfBounds.new }
  end

  def pop
    if @length == 0
      yield
    else
      @length -= 1
      value = @buffer[@length]
      (@buffer + @length).clear
      value
    end
  end

  def pop(n)
    if n < 0
      raise ArgumentError.new("can't pop negative count")
    end

    n = Math.min(n, @length)
    ary = Array(T).new(n) { |i| @buffer[@length - n + i] }

    @length -= n
    (@buffer + @length).clear(n)

    ary
  end

  def pop?
    pop { nil }
  end

  def product(ary : Array(U))
    result = Array({T, U}).new(length * ary.length)
    product(ary) do |x, y|
      result << {x, y}
    end
    result
  end

  def product(ary, &block)
    self.each { |a| ary.each { |b| yield a, b } }
  end

  def push(value : T)
    check_needs_resize
    @buffer[@length] = value
    @length += 1
    self
  end

  def push(*values : T)
    values.each do |value|
      self << value
    end
  end

  def replace(other : Array)
    @length = other.length
    resize_to_capacity(@length) if @length > @capacity
    @buffer.copy_from(other.buffer, other.length)
    self
  end

  def reverse
    Array(T).new(length) { |i| @buffer[length - i - 1] }
  end

  def reverse!
    i = 0
    j = length - 1
    while i < j
      @buffer.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def reverse_each
    (length - 1).downto(0) do |i|
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
    (length - 1).downto(0) do |i|
      if yield @buffer[i]
        return i
      end
    end
    nil
  end

  def sample
    raise IndexOutOfBounds.new if @length == 0
    @buffer[rand(@length)]
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
      if n >= @length
        return dup.shuffle!
      end

      ary = Array(T).new(n) { |i| @buffer[i] }
      buffer = ary.buffer

      n.upto(@length - 1) do |i|
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
    shift { raise IndexOutOfBounds.new }
  end

  def shift
    if @length == 0
      yield
    else
      value = @buffer[0]
      @length -= 1
      @buffer.move_from(@buffer + 1, @length)
      (@buffer + @length).clear
      value
    end
  end

  def shift(n)
    if n < 0
      raise ArgumentError.new("can't shift negative count")
    end

    n = Math.min(n, @length)
    ary = Array(T).new(n) { |i| @buffer[i] }

    @buffer.move_from(@buffer + n, @length - n)
    @length -= n
    (@buffer + @length).clear(n)

    ary
  end

  def shift?
    shift { nil }
  end

  def size
    @length
  end

  def shuffle
    dup.shuffle!
  end

  def shuffle!
    @buffer.shuffle!(length)
    self
  end

  def sort
    dup.sort!
  end

  def sort(&block: T, T -> Int32)
    dup.sort! &block
  end

  def sort!
    Array.quicksort!(@buffer, @length)
    self
  end

  def sort!(&block: T, T -> Int32)
    Array.quicksort!(@buffer, @length, block)
    self
  end

  def sort_by(&block: T -> _)
    dup.sort_by! &block
  end

  def sort_by!(&block: T -> _)
    sort! { |x, y| block.call(x) <=> block.call(y) }
  end

  def swap(index0, index1)
    index0 += length if index0 < 0
    index1 += length if index1 < 0

    unless (0 <= index0 < length) && (0 <= index1 < length)
      raise IndexOutOfBounds.new
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

  # Returns a new array by removing duplicate values in `self`.
  #
  # ```
  # a = [ "a", "a", "b", "b", "c" ]
  # a.uniq   # => ["a", "b", "c"]
  # a        # => [ "a", "a", "b", "b", "c" ]
  # ```
  def uniq
    uniq &.itself
  end

  # Returns a new array by removing duplicate values in `self`, using the block's
  # value for comparison.
  #
  # ```
  # a = [{"student","sam"}, {"student","george"}, {"teacher","matz"}]
  # a.uniq { |s| s[0] } # => [{"student", "sam"}, {"teacher", "matz"}]
  # a                   # => [{"student", "sam"}, {"student", "george"}, {"teacher", "matz"}]
  # ```
  def uniq(&block : T -> _)
    if length <= 1
      dup
    else
      hash = to_lookup_hash { |elem| yield elem }
      hash.values
    end
  end

  # Removes duplicate elements from `self`. Returns `self`.
  #
  # ```
  # a = [ "a", "a", "b", "b", "c" ]
  # a.uniq!   # => ["a", "b", "c"]
  # a         # => ["a", "b", "c"]
  # ```
  def uniq!
    uniq! &.itself
  end

  # Removes duplicate elements from `self`, using the block's value for comparison. Returns `self`.
  #
  # ```
  # a = [{"student","sam"}, {"student","george"}, {"teacher","matz"}]
  # a.uniq! { |s| s[0] } # => [{"student", "sam"}, {"teacher", "matz"}]
  # a                    # => [{"student", "sam"}, {"teacher", "matz"}]
  # ```
  def uniq!
    if length <= 1
      return self
    end

    hash = to_lookup_hash { |elem| yield elem }
    if length == hash.length
      return self
    end

    old_length = @length
    @length = hash.length
    removed = old_length - @length
    return self if removed == 0

    ptr = @buffer
    hash.each do |k, v|
      ptr.value = v
      ptr += 1
    end

    (@buffer + @length).clear(removed)

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
    pairs = Array({T, U}).new(length)
    zip(other) { |x, y| pairs << {x, y} }
    pairs
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @length == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
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
    quicksort!(a, (r - a) + 1, comp)
    quicksort!(l, (a + n) - l, comp)
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
    quicksort!(a, (r - a) + 1)
    quicksort!(l, (a + n) - l)
  end

  private def check_index_out_of_bounds(index)
    index += length if index < 0
    unless 0 <= index < length
      raise IndexOutOfBounds.new
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
      return stop if @index >= @array.length

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

    def initialize(@array : Array(T), @index = array.length - 1)
    end

    def next
      return stop if @index < 0

      value = @array.at(@index) { stop }
      @index -= 1
      value
    end

    def rewind
      @index = @array.length - 1
      self
    end
  end
end
