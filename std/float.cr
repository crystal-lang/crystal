require "float32"
require "float64"

class Float
  def +@
    self
  end

  def round
    (self + 0.5).to_i32
  end
end