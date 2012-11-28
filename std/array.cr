class Array
  def each
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end

  def join(sep = "")
    str = ""
    each_with_index do |elem, i|
      str += sep if i > 0
      str += elem.to_s
    end
    str
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