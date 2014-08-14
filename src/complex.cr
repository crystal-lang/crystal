struct Complex
  getter real
  getter imag

  def initialize(real : Number, imag : Number)
    @real = real.to_f
    @imag = imag.to_f
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

  def to_s(io : IO)
    io << real
    io << " + "
    io << imag
    io << "i"
  end
end
