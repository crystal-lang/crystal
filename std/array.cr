class Array
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
    str = ""
    each_with_index do |elem, i|
      str += "\n" if i > 0
      str += elem.to_s
    end
    str
  end
end