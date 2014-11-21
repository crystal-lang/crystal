struct Complex
  getter real
  getter imag

  def initialize(real : Number, imag : Number)
    @real = real.to_f
    @imag = imag.to_f
  end

  def ==(other : Complex)
    real == other.real && imag == other.imag
  end

  def ==(other : Number)
    self == other.to_c
  end

  def ==(other)
    false
  end

  def to_s(io : IO)
    io << real
    io << (imag >= 0 ? " + " : " - ")
    io << imag.abs
    io << "i"
  end

  def abs
    Math.hypot(real, imag)
  end

  def abs2
    real * real + imag * imag
  end

  def phase
    Math.atan2(imag, real)
  end

  def polar
    [abs, phase]
  end

  def conj
    Complex.new(real, - imag)
  end

  def inv
    conj / abs2
  end

  def +(other : Complex)
    Complex.new(real + other.real, imag + other.imag)
  end

  def +(other : Number)
    Complex.new(real + other, imag)
  end

  def -
    Complex.new(- real, - imag)
  end

  def -(other : Complex)
    Complex.new(real - other.real, imag - other.imag)
  end

  def -(other : Number)
    Complex.new(real - other, imag)
  end

  def *(other : Complex)
    Complex.new(real * other.real - imag * other.imag, real * other.imag + imag * other.real)
  end

  def *(other : Number)
    Complex.new(real * other, imag * other)
  end

  def /(other : Complex)
    if other.real <= other.imag
      r = other.real / other.imag
      d = other.imag + r * other.real
      Complex.new((real * r + imag) / d, (imag * r - real) / d)
    else
      r = other.imag / other.real
      d = other.real + r * other.imag
      Complex.new((real + imag * r) / d, (imag - real * r) / d)
    end 
  end

  def /(other : Number)
    Complex.new(real / other, imag / other)
  end
end

struct Number
  def to_c
    Complex.new(self, 0)
  end

  def i
    Complex.new(0, self)
  end

  def ==(other : Complex)
    to_c == other
  end

  def +(other : Complex)
    Complex.new(self + other.real, other.imag)
  end

  def -(other : Complex)
    Complex.new(self - other.real, - other.imag)
  end

  def *(other : Complex)
    Complex.new(self * other.real, self * other.imag)
  end

  def /(other : Complex)
    self * inv(other)
  end
end
