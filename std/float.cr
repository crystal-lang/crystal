class Float
  def ==(other)
    false
  end

  def -@
    0.0f - self
  end

  def +@
    self
  end

  def **(other)
    self ** other.to_f
  end

  def to_s
    to_d.to_s
  end
end