require "enumerable"
require "pointer"

generic class Array
  include Enumerable

  def initialize(initial_capacity = 16)
    @length = 0
    @capacity = initial_capacity
    @buffer = Pointer.malloc(initial_capacity)
  end

  def initialize(size, value)
    @length = size
    @capacity = size
    @buffer = Pointer.malloc(size, value)
  end

  def self.new(size)
    ary = Array.new(size)
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

  def [](index)
    @buffer[index]
  end

  def []=(index, value)
    @buffer[index] = value
  end

  def push(value)
    if @length == @capacity
      @capacity *= 2
      @buffer = @buffer.realloc(@capacity)
    end
    @buffer[@length] = value
    @length += 1
  end

  def pop
    return nil if @length == 0
    @length -= 1
    @buffer[@length]
  end

  def <<(value)
    push(value)
  end

  def first
    self[0]
  end

  def last
    self[@length - 1]
  end

  def each
    length.times do |i|
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

  def ==(other : Array)
    return false if @length != other.length
    each_with_index do |item, i|
      return false if item != other[i]
    end
    true
  end

  def to_s
    str = StringBuilder.new
    str << "["
    each_with_index do |elem, i|
      str << ", " if i > 0
      str << elem.inspect
    end
    str << "]"
    str.inspect
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