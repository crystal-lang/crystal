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

  def abs
    self >= 0 ? self : -self
  end

  def **(other)
    to_d ** other
  end

  def [](bit)
    self & (1 << bit) == 0 ? 0 : 1
  end

  def gcd(other : Int)
    self == 0 ? other.abs : (other % self).gcd(self)
  end

  def hash
    self
  end

  def succ
    self + 1
  end

  def times(&block : Int -> )
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
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%d", self)
    end
  end
end
