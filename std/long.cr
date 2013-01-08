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

  def to_s
    str = String.new(22)
    C.sprintf(str.cstr, "%ld", self)
    str
  end
end