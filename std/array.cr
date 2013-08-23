require "enumerable"
require "pointer"
require "range"

class Array(T)
  include Enumerable

  def initialize(initial_capacity = 16)
    @length = 0
    @capacity = initial_capacity
    @buffer = Pointer(T).malloc(initial_capacity)
  end

  def initialize(size, value : T)
    @length = size
    @capacity = size
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

  def length
    @length
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

  def [](index : Int)
    index += length if index < 0
    raise "Array index out of bounds (#{index} of #{length})" if index >= length || index < 0
    @buffer[index]
  end

  def []=(index : Int, value : T)
    index += length if index < 0
    raise "Array index out of bounds (#{index} of #{length})" if index >= length || index < 0
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
    Array(T).new(count) { |i| @buffer[start + i] }
  end

  def push(value : T)
    check_needs_resize
    @buffer[@length] = value
    @length += 1
    self
  end

  def pop
    return nil if @length == 0
    @length -= 1
    @buffer[@length]
  end

  def shift
    return nil if @length == 0
    value = @buffer[0]
    @length -=1
    @buffer.memmove(@buffer + 1, @length)
    value
  end

  def unshift(obj : T)
    insert 0, obj
  end

  def <<(value : T)
    push(value)
  end

  def first
    self[0]
  end

  def last
    self[@length - 1]
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
    return nil if index < 0 || index >= length

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
    select { |x| !x.nil? }
  end

  def compact!
    delete nil
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

  def map!
    length.times do |i|
      @buffer[i] = yield @buffer[i]
    end
    nil
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
      tmp = @buffer[i]
      @buffer[i] = @buffer[j]
      @buffer[j] = tmp
      i += 1
      j -= 1
    end
    self
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

  def buffer
    @buffer
  end

  def to_a
    self
  end

  def max
    max = self[0]
    1.upto(length - 1) do |i|
      max = self[i] if self[i] > max
    end
    max
  end

  def +(other : Array(U))
    new_length = length + other.length
    ary = Array(T | U).new(new_length)
    ary.length = new_length
    ary.buffer.memcpy(buffer, length)
    (ary.buffer + length).memcpy(other.buffer, other.length)
    ary
  end

  def concat(other : Array(T))
    other.each do |elem|
      push elem
    end
    self
  end

  def ==(other : Array)
    return false if @length != other.length
    each_with_index do |item, i|
      return false if item != other[i]
    end
    true
  end

  def to_s
    String.build do |str|
      str << "["
      each_with_index do |elem, i|
        str << ", " if i > 0
        str << elem.inspect
      end
      str << "]"
    end
  end

  def sort!
    quicksort 0, length - 1
    self
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

  def swap(i, j)
    temp = self[i]
    self[i] = self[j]
    self[j] = temp
  end

  def partition(left, right, pivot_index)
    pivot_value = self[pivot_index]
    swap pivot_index, right
    store_index = left
    left.upto(right) do |i|
      if self[i] < pivot_value
        swap i, store_index
        store_index += 1
      end
    end
    swap store_index, right
    store_index
  end

  def quicksort(left, right)
    if left < right
      pivot_index = (left + right) / 2
      pivot_new_index = partition left, right, pivot_index
      quicksort left, pivot_new_index - 1
      quicksort pivot_new_index + 1, right
    end
  end
end
