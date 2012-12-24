class Complex
  def initialize(real, imag)
    @real = real
    @imag = imag
  end

  def real
    @real
  end

  def imag
    @imag
  end

  def +(other)
    Complex.new(real + other.real, imag + other.imag)
  end

  def *(other)
    Complex.new(real * other.real - imag * other.imag, real * other.imag + imag * other.real)
  end

  def abs
    Math.sqrt(real * real + imag * imag)
  end

  def to_s
    "#{real} + #{imag}i"
  end
end