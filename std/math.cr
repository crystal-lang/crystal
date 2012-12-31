lib C
  fun sqrtf(f : Float) : Float
end

module Math
  PI = 3.14159265358979323846

  def self.sqrt(value)
    C.sqrtf value
  end
end