require "int8"
require "int16"
require "int32"
require "int64"
require "uint8"
require "uint16"
require "uint32"
require "uint64"

class Int
  def +@
    self
  end

  def abs
    self >= 0 ? self : -self
  end

  def **(other : Int)
    (to_f64 ** other).to_i
  end

  def **(other)
    to_f64 ** other
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

  def times(&block : self -> )
    i = self ^ self
    while i < self
      yield i
      i += 1
    end
    self
  end

  def upto(n, &block : self -> )
    if self <= n
      x = self
      while x <= n
        yield x
        x += 1
      end
    end
    self
  end

  def downto(n, &block : self -> )
    if self >= n
      x = self
      while x >= n
        yield x
        x -= 1
      end
    end
    self
  end
end