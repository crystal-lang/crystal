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
    String.new(22) do |buffer|
      C.sprintf(buffer, "%ld", self)
    end
  end
end