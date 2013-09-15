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

  def modulo(other)
    self % other
  end
end

class Int8
  MIN = -128_i8
  MAX =  127_i8

  def ==(other)
    false
  end

  def -@
    0_i8 - self
  end

  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhd", self)
    end
  end
end

class Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def ==(other)
    false
  end

  def -@
    0_i16 - self
  end

  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hd", self)
    end
  end
end

class Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def ==(other)
    false
  end

  def -@
    0 - self
  end

  def to_s
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%d", self)
    end
  end
end

class Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def ==(other)
    false
  end

  def -@
    0_i64 - self
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%ld", self)
    end
  end
end

class UInt8
  MIN = 0_u8
  MAX = 255_u8

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(5) do |buffer|
      C.sprintf(buffer, "%hhu", self)
    end
  end
end

class UInt16
  MIN = 0_u16
  MAX = 65535_u16

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(7) do |buffer|
      C.sprintf(buffer, "%hu", self)
    end
  end
end

class UInt32
  MIN = 0_u32
  MAX = 4294967295_u32

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(12) do |buffer|
      C.sprintf(buffer, "%u", self)
    end
  end
end

class UInt64
  MIN = 0_u64
  MAX = 18446744073709551615_u64

  def ==(other)
    false
  end

  def to_s
    String.new_with_capacity(22) do |buffer|
      C.sprintf(buffer, "%lu", self)
    end
  end
end
