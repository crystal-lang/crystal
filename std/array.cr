class Array
  def initialize
    @length = 0
    @capacity = 16
    @buffer = Pointer.malloc(16)
  end

  def length
    @length
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

  def <<(value)
    if @length == @capacity
      @capacity *= 2
      @buffer = @buffer.realloc(@capacity)
    end
    @buffer[@length] = value
    @length += 1
  end

  def each
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end

  def to_a
    self
  end

  def to_s
    str = "["
    each_with_index do |elem, i|
      str += ", " if i > 0
      str += elem.inspect
    end
    str += "]"
    str
  end

  def sort!
    quicksort 0, length - 1
    self
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
    (left...right).each do |i|
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