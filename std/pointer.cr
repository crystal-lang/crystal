class Pointer
  def [](offset)
    (self + offset).value
  end

  def []=(offset, value)
    (self + offset).value = value
  end
end