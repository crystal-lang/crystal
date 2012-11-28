lib C
  fun sqrtf(f : Float) : Float
end

module Math
  def self.sqrt(value)
    C.sqrtf value
  end
end