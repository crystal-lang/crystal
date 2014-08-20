struct Int
  def +
    self
  end

  def ~
    self ^ -1
  end

  # TODO: enable in next release
  # def /(x : Int)
  #   if x == 0
  #     raise DivisionByZero.new
  #   end

  #   unsafe_div x
  # end

  def abs
    self >= 0 ? self : -self
  end

  def floor
    self
  end

  def ceil
    self
  end

  def round
    self
  end

  def **(other : Int)
    (to_f64 ** other).to_i
  end

  def **(other)
    to_f64 ** other
  end

  def bit(bit)
    self & (1 << bit) == 0 ? 0 : 1
  end

  def gcd(other : Int)
    self == 0 ? other.abs : (other % self).gcd(self)
  end

  def lcm(other : Int)
    (self * other).abs / gcd(other)
  end

  def divisible_by?(num)
    self % num == 0
  end

  def even?
    divisible_by? 2
  end

  def odd?
    !even?
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
    x = self
    while x <= n
      yield x
      x += 1
    end
    self
  end

  def downto(n, &block : self -> )
    x = self
    while x >= n
      yield x
      x -= 1
    end
    self
  end

  def to(n, &block : self -> )
    if self < n
      upto(n) { |i| yield i }
    elsif self > n
      downto(n) { |i| yield i }
    else
      yield self
    end
    self
  end

  def modulo(other)
    self % other
  end

  def to_s(radix : Int)
    String.build do |io|
      to_s(radix, io)
    end
  end

  def to_s(radix : Int, io : IO)
    if radix < 1 || radix > 36
      raise "Invalid radix #{radix}"
    end

    if self == 0
      io << "0"
      return
    end

    str = StringIO.new
    num = self

    if num < 0
      str.write_byte '-'.ord.to_u8
      num = num.abs
      init = 1
    else
      init = 0
    end

    while num > 0
      digit = num % radix
      if digit >= 10
        str.write_byte ('a'.ord + digit - 10).to_u8
      else
        str.write_byte ('0'.ord + digit).to_u8
      end
      num /= radix
    end

    # Reverse buffer
    buffer = str.buffer
    init.upto(str.length / 2 + init - 1) do |i|
      buffer.swap(i, str.length - i - 1 + init)
    end

    io << str.to_s
  end

  def to_modet
    ifdef darwin
      to_u16
    elsif linux
      to_u32
    end
  end

  def to_sizet
    ifdef x86_64
      to_u64
    else
      to_u32
    end
  end

  def to_timet
    ifdef x86_64
      to_i64
    else
      to_i32
    end
  end

  macro generate_to_s(capacity)
    def to_s
      String.new_with_capacity_and_length({{capacity}}) do |buffer|
        to_s PointerIO.new(pointerof(buffer))
      end
    end

    def to_s(io : IO)
      if self == 0
        io.write_byte '0'.ord.to_u8
        return 1
      end

      chars :: UInt8[{{capacity}}]
      position = {{capacity}} - 1
      num = self
      negative = num < 0

      while num != 0
        digit = (num % 10).abs
        chars.buffer[position] = ('0'.ord + digit).to_u8
        position -= 1
        num /= 10
      end

      if negative
        chars.buffer[position] = '-'.ord.to_u8
        position -= 1
      end

      length = {{capacity}} - 1 - position
      io.write(chars.to_slice + position + 1, length)
      length
    end
  end
end

struct Int8
  MIN = -128_i8
  MAX =  127_i8

  def -
    0_i8 - self
  end

  generate_to_s 5
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def -
    0_i16 - self
  end

  generate_to_s 7
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def -
    0 - self
  end

  generate_to_s 12
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def -
    0_i64 - self
  end

  generate_to_s 22
end

struct UInt8
  MIN = 0_u8
  MAX = 255_u8

  def abs
    self
  end

  generate_to_s 5
end

struct UInt16
  MIN = 0_u16
  MAX = 65535_u16

  def abs
    self
  end

  generate_to_s 7
end

struct UInt32
  MIN = 0_u32
  MAX = 4294967295_u32

  def abs
    self
  end

  generate_to_s 12
end

struct UInt64
  MIN = 0_u64
  MAX = 18446744073709551615_u64

  def abs
    self
  end

  generate_to_s 22
end
