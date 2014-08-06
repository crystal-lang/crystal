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

  def count
    @length
  end

  def size
    @length
  end

  def empty?
    @length == 0
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

  def [](index : Int)
    at(index)
  end

  def []?(index : Int)
    at(index) { nil }
  end

  def []=(index : Int, value : T)
    index += length if index < 0
    raise IndexOutOfBounds.new if index >= length || index < 0
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

  def push(value : T)
    check_needs_resize
    @buffer[@length] = value
    @length += 1
    self
  end

  def pop
    pop { raise IndexOutOfBounds.new }
  end

  def pop?
    pop { nil }
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
    ary = Array(T).new(n) { |i| @buffer[@length - n + i] }

    @length -= n

    ary
  end

  def shift
    shift { raise IndexOutOfBounds.new }
  end

  def shift?
    shift { nil }
  end

  def shift
    if @length == 0
      yield
    else
      value = @buffer[0]
      @length -=1
      @buffer.memmove(@buffer + 1, @length)
      value
    end
  end

  def shift(n)
    if n < 0
      raise ArgumentError.new("can't shift negative count")
    end

    n = Math.min(n, @length)
    ary = Array(T).new(n) { |i| @buffer[i] }

    @buffer.memmove(@buffer + n, @length - n)
    @length -= n

    ary
  end

  def unshift(obj : T)
    insert 0, obj
  end

  def <<(value : T)
    push(value)
  end

  def first
    raise IndexOutOfBounds.new if @length == 0
    @buffer[0]
  end

  def first?
    @length == 0 ? nil : @buffer[0]
  end

  def last
    raise IndexOutOfBounds.new if @length == 0
    @buffer[@length - 1]
  end

  def last?
    return nil if @length == 0
    @buffer[@length - 1]
  end

  def insert(index : Int, obj : T)
    check_needs_resize
    index += length if index < 0
    (@buffer + index + 1).memmove(@buffer + index, length - index)
    @buffer[index] = obj
    @length += 1
    self
  end

  def delete_at(index : Int)
    index += length if index < 0
    raise IndexOutOfBounds.new if index < 0 || index >= length

    elem = @buffer[index]
    (@buffer + index).memmove(@buffer + index + 1, length - index - 1)
    @length -= 1
    elem
  end

  def delete(obj)
    delete_if { |e| e == obj }
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

  def &(other : Array(U))
    hash = other.each_with_object(Hash(T, Bool).new) { |o, h| h[o] = true }
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

  def -(other : Array(U))
    ary = Array(T).new(length - other.length)
    hash = other.each_with_object(Hash(T, Bool).new) { |o, h| h[o] = true }
    each do |obj|
      ary << obj unless hash.has_key?(obj)
    end
    ary
  end

  def compact
    compact_map { |x| x }
  end

  def compact!
    delete nil
  end

  def compact(array)
    each do |elem|
      array.push elem if elem
    end
  end

  # def flatten(target : Array(U))
  #   flatten_append target, self, false
  #   target
  # end

  def map(&block : T -> U)
    ary = Array(U).new(length)
    ary.length = length
    each_with_index do |e, i|
      ary.buffer[i] = yield e
    end
    ary
  end

  def map_with_index(&block : T, Int32 -> U)
    ary = Array(U).new(length)
    ary.length = length
    each_with_index do |e, i|
      ary.buffer[i] = yield e, i
    end
    ary
  end

  def map!
    @buffer.map!(length) { |e| yield e }
    self
  end

  def dup
    ary = Array(T).new(length)
    ary.length = length
    ary.buffer.memcpy(buffer, length)
    ary
  end

  def clone
    ary = Array(T).new(length)
    ary.length = length
    each_with_index do |e, i|
      ary.buffer[i] = e.clone
    end
    ary
  end

  def replace(other : Array)
    @length = other.length
    resize_to_capacity(@length) if @length > @capacity
    @buffer.memcpy(other.buffer, other.length)
    self
  end

  def reverse
    ary = Array(T).new(length)
    i = 0
    reverse_each do |obj|
      ary.buffer[i] = obj
      i += 1
    end
    ary.length = length
    ary
  end

  def reverse!
    i = 0
    j = length - 1
    while i != j
      @buffer.swap(i, j)
      i += 1
      j -= 1
    end
    self
  end

  def uniq!(&block : T -> U)
    uniq_elements = Set(U).new
    delete_if do |elem|
      key = yield elem
      if uniq_elements.includes?(key)
        true
      else
        uniq_elements.add(key)
        false
      end
    end
    self
  end

  def uniq!
    uniq! { |x| x }
  end

  def clear
    @length = 0
  end

  def each
    length.times do |i|
      yield @buffer[i]
    end
    self
  end

  def reverse_each
    (length - 1).downto(0) do |i|
      yield @buffer[i]
    end
    self
  end

  def each_index
    length.times do |i|
      yield i
    end
  end

  def buffer
    @buffer
  end

  def to_unsafe
    @buffer
  end

  def to_a
    self
  end

  def +(other : Array(U))
    new_length = length + other.length
    ary = Array(T | U).new(new_length)
    ary.length = new_length
    ary.buffer.memcpy(buffer, length)
    (ary.buffer + length).memcpy(other.buffer, other.length)
    ary
  end

  def concat(other : Array)
    other_length = other.length
    new_length = length + other_length
    if new_length > @capacity
      resize_to_capacity(Math.pw2ceil(new_length))
    end

    (@buffer + @length).memcpy(other.buffer, other_length)
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

  def product(ary)
    self.each { |a| ary.each { |b| yield a, b } }
  end

  def zip(other : Array)
    each_with_index do |elem, i|
      yield elem, other[i]
    end
  end

  def swap(index0, index1)
    index0 += length if index0 < 0
    index1 += length if index1 < 0

    raise IndexOutOfBounds.new if index0 >= length || index0 < 0 || index1 >= length || index1 < 0

    @buffer[index0], @buffer[index1] = @buffer[index1], @buffer[index0]

    self
  end

  def ==(other : Array)
    equals?(other) { |x, y| x == y }
  end

  def equals?(other : Array)
    return false if @length != other.length
    each_with_index do |item, i|
      return false unless yield(item, other[i])
    end
    true
  end

  def hash
    hash = 31 * @length
    each do |elem|
      hash = 31 * hash + elem.hash
    end
    hash
  end

  def inspect(io : IO)
    to_s io
  end

  def to_s(io : IO)
    executed = exec_recursive(:to_s) do
      io << "["
      join ", ", io, &.inspect(io)
      io << "]"
    end
    io << "[...]" unless executed
  end

  def sort!
    Array(T).quicksort!(@buffer, @length)
    self
  end

  def sort!(&block: T, T -> Int32)
    Array(T).quicksort!(@buffer, @length, block)
    self
  end

  def sort_by!(&block: T -> U)
    sort! { |x, y| block.call(x) <=> block.call(y) }
  end

  def sort_by(&block: T -> U)
    dup.sort_by! &block
  end

  def sort
    dup.sort!
  end

  def sort(&block: T, T -> Int32)
    x = dup
    Array(T).quicksort!(x.buffer, x.length, block)
    x
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

  def shuffle!
    @buffer.shuffle!(length)
    self
  end

  def shuffle
    dup.shuffle!
  end

  # protected

  def length=(length)
    @length = length
  end

  # private

  def check_needs_resize
    resize_to_capacity(@capacity * 2) if @length == @capacity
  end

  def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end

  # def flatten_append(target, source : Array(U), modified)
  #   source.each do |obj|
  #     modified |= flatten_append target, obj, true
  #   end
  #   modified
  # end

  # def flatten_append(target, source, modified)
  #   target.push source
  #   false
  # end

  def self.quicksort!(a, n, comp)
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

  def self.quicksort!(a, n)
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
end
