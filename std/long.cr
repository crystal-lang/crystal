class Long
  def ==(other)
    false
  end

  def -@
    0L - self
  end

  def +@
    self
  end
end