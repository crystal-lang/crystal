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
end