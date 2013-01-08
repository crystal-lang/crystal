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
    str = String.new(12)
    C.sprintf(str.cstr, "%g", self)
    str
  end
end