class Array
  def each
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end
end