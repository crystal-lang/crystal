class Array(T)
  include Enumerable

  getter length

  def initialize(initial_capacity = 3 : Int)
    initial_capacity = Math.max(initial_capacity, 3)
    @length = 0
    @capacity = initial_capacity.to_i
    @buffer = Pointer(T).malloc(initial_capacity)
  end

  def initialize(size, value : T)
    if size < 0
      raise ArgumentError.new("negative array size: #{size}")
    end

    @length = size
    @capacity = Math.max(size, 3)
    @buffer = Pointer(T).malloc(size, value)
  end

  def self.new(size, &block : Int32 -> T)
    ary = Array(T).new(size)
    ary.length = size
    size.times do |i|
      ary.buffer[i] = yield i
    end
    ary
  end

  def ==(other : Array)
    equals?(other) { |x, y| x == y }
  end

  def &(other : Array(U))
    hash = other.to_lookup_hash
    ary = Array(T).new(Math.min(length, other.length))
    i = 0
    each do |obj|
      if hash.has_key?(obj)
        ary.buffer[i] = obj
        i += 1
      end
    end
    ary.length = i
    ary
  end

  def |(other : Array(U))
    ary = Array(T | U).new(length + other.length)
    hash = Hash(T, Bool).new
    i = 0
    each do |obj|
      ary.buffer[i] = obj
      i += 1
      hash[obj] = true
    end
    other.each do |obj|
      unless hash.has_key?(obj)
        ary.buffer[i] = obj
        i += 1
      end
    end
    ary.length = i
    ary
  end

  def +(other : Array(U))
    new_length = length + other.length
    ary = Array(T | U).new(new_length)
    ary.length = new_length
    ary.buffer.copy_from(buffer, length)
    (ary.buffer + length).copy_from(other.buffer, other.length)
    ary
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
    length <= 0 ? Array(T).new : self[from, length]
  end

  def [](start : Int, count : Int)
    count = Math.min(count, length)
    Array(T).new(count) { |i| @buffer[start + i] }
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

  def buffer
    @buffer
  end

  def clear
    @length = 0
  end

  def clone
    ary = Array(T).new(length)
    ary.length = length
    each_with_index do |e, i|
      ary.buffer[i] = e.clone
    end
    ary
  end

  def compact
    compact_map { |x| x }
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
      @length -= (i1 - i2)
      true
    else
      false
    end
  end

  def dup
    ary = Array(T).new(length)
    ary.length = length
    ary.buffer.copy_from(buffer, length)
    ary
  end

  def each
    length.times do |i|
      yield @buffer[i]
    end
    self
  end

  def each_index
    length.times do |i|
      yield i
    end
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

  def length=(length)
    @length = length
  end

  def map
    Array.new(length) { |i| yield buffer[i] }
  end

  def map!
    @buffer.map!(length) { |e| yield e }
    self
  end

  def map_with_index
    Array.new(length) { |i| yield buffer[i], i }
  end

  def pop
    pop { raise IndexOutOfBounds.new }
  end

  def pop
    if @length == 0
      yield
    else
      @length -= 1
      @buffer[@length]
    end
  end

  def pop(n)
    if n < 0
      raise ArgumentError.new("can't pop negative count")
    end

    n = Math.min(n, @length)
    ary = Array.new(n) { |i| @buffer[@length - n + i] }

    @length -= n

    ary
  end

  def pop?
    pop { nil }
  end

  def product(ary)
    self.each { |a| ary.each { |b| yield a, b } }
  end

  def push(value : T)
    check_needs_resize
    @buffer[@length] = value
    @length += 1
    self
  end

  def replace(other : Array)
    @length = other.length
    resize_to_capacity(@length) if @length > @capacity
    @buffer.copy_from(other.buffer, other.length)
    self
  end

  def reverse
    ary = Array(T).new(length)
    ary.length = length
    i = 0
    reverse_each do |obj|
      ary.buffer[i] = obj
      i += 1
    end
    ary
  end

  def reverse!
    i = 0
    j = length - 1
    while i != j
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

      ary = Array.new(n) { |i| @buffer[i] }
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
      @length -=1
      @buffer.move_from(@buffer + 1, @length)
      value
    end
  end

  def shift(n)
    if n < 0
      raise ArgumentError.new("can't shift negative count")
    end

    n = Math.min(n, @length)
    ary = Array.new(n) { |i| @buffer[i] }

    @buffer.move_from(@buffer + n, @length - n)
    @length -= n

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

  def sort_by(&block: T -> U)
    dup.sort_by! &block
  end

  def sort_by!(&block: T -> U)
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
  
  def to_h
    result = {first.first => last.last}

    each_with_index do |pair, index|
      result[pair.first] = pair.last
    end

    result
  end

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
  
  def transpose
    result = Array(T).new

    first.length.times do |i|
      result << map { |pair| pair[i] }
    end

    result
  end

  def uniq
    uniq { |x| x }
  end

  def uniq(&block : T -> U)
    if length <= 1
      dup
    else
      hash = to_lookup_hash { |elem| yield elem }
      hash.values
    end
  end

  def uniq!
    uniq! { |x| x }
  end

  def uniq!(&block : T -> U)
    if length <= 1
      return self
    end

    hash = to_lookup_hash { |elem| yield elem }
    if length == hash.length
      return self
    end

    @length = hash.length

    ptr = @buffer
    hash.each do |k, v|
      ptr.value = v
      ptr += 1
    end

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
end
