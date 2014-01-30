struct StaticArray(T, N)
  def [](index : Int)
    buffer[index]
  end

  def []=(index : Int, value : T)
    buffer[index] = value
  end

  def length
    N
  end

  def buffer
    pointerof(@buffer)
  end
end

