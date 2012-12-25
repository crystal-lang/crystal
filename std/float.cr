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
end