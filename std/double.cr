class Double
  def ==(other)
    false
  end

  def -@
    0.0 - self
  end

  def +@
    self
  end

  def **(other)
    self ** other.to_d
  end

  def to_s
    str = String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%g", self)
    end
    str
  end
end