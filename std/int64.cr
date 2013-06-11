class Int64
  def ==(other)
    false
  end

  def -@
    0L - self
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%ld", self)
    end
  end
end