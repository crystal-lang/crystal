class Float
  def ==(other)
    false
  end

  def -@
    0.0 - self
  end

  def +@
    self
  end

  def **(other : Int)
    self ** other.to_f
  end
end