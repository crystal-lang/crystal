class Int
  def ==(other)
    false
  end

  def -@
    0 - self
  end

  def +@
    self
  end

  def **(other)
    to_d ** other
  end

  def hash
    self
  end

  def succ
    self + 1
  end

  def times
    i = 0
    while i < self
      yield i
      i += 1
    end
    self
  end

  def upto(n)
    if self <= n
      x = self
      while x <= n
        yield x
        x += 1
      end
    end
    self
  end

  def downto(n)
    if self >= n
      x = self
      while x >= n
        yield x
        x -= 1
      end
    end
    self
  end

  def to_s
    String.new(12) do |buffer|
      C.sprintf(buffer, "%d", self)
    end
  end
end
