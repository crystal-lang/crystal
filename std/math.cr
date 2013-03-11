lib C
  fun exp(x : Double) : Double
end

module Math
  E  = C.exp(1.0)
  PI = 3.14159265358979323846

  def self.sqrt(value : Int)
    sqrt value.to_d
  end

  def self.min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def self.max(value1, value2)
    value1 >= value2 ? value1 : value2
  end
end