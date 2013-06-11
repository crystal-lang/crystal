class Int32
  def ==(other)
    false
  end

  def -@
    0 - self
  end

  # TODO: allow self as block spec and move to Int
  def times(&block : Int32 -> )
    i = 0
    while i < self
      yield i
      i += 1
    end
    self
  end

  def to_s
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%d", self)
    end
  end
end
