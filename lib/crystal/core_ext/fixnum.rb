class Fixnum
  def int
    Crystal::Int.new self
  end

  def float
    Crystal::Float.new self.to_f
  end
end
