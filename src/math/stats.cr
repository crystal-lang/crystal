module Stats
  extend self
  
  def mean(value : StaticArray | Array | Tuple)
    value.sum / value.length
  end

  def mean(value : Enumerable)
    value.sum / value.count
  end
end
