lib C
  fun acos(x : Double) : Double
  fun acosh(x : Double) : Double
  fun asin(x : Double) : Double
  fun asinh(x : Double) : Double
  fun atan(x : Double) : Double
  fun atan2(y : Double, x : Double) : Double
  fun cbrt(x : Double) : Double
  fun cos(x : Double) : Double
  fun erf(x : Double) : Double
  fun erfc(x : Double) : Double
  fun exp(x : Double) : Double
  fun hypot(x : Double, y : Double) : Double
  fun ldexp(flt : Double, int : Int) : Double
  fun lgamma(x : Double) : Double
  fun log(x : Double) : Double
  fun log10(x : Double) : Double
  fun log2(x : Double) : Double
  fun sin(x : Double) : Double
  fun sinh(x : Double) : Double
  fun tan(x : Double) : Double
  fun tanh(x : Double) : Double
  fun tgamma(x : Double) : Double
end

module Math
  E  = C.exp(1.0)
  PI = 3.14159265358979323846

  def self.acos(value)
    C.acos(value.to_d)
  end

  def self.acosh(value)
    C.acosh(value.to_d)
  end

  def self.asin(value)
    C.asin(value.to_d)
  end

  def self.asinh(value)
    C.asinh(value.to_d)
  end

  def self.atan(value)
    C.atan(value.to_d)
  end

  def self.atan2(y, x)
    C.atan2(y.to_d, x.to_d)
  end

  def self.cbrt(value)
    C.cbrt(value.to_d)
  end

  def self.cos(value)
    C.cos(value.to_d)
  end

  def self.erf(value)
    C.erf(value.to_d)
  end

  def self.erfc(value)
    C.erfc(value.to_d)
  end

  def self.exp(value)
    C.exp(value.to_d)
  end

  def self.gamma(value)
    C.tgamma(value.to_d)
  end

  def self.hypot(x, y)
    C.hypot(x.to_d, y.to_d)
  end

  def self.ldexp(flt, int : Int)
    C.ldexp(flt.to_d, int)
  end

  def self.log(numeric)
    C.log(numeric.to_d)
  end

  def self.log(numeric, base)
    log(numeric) / log(base)
  end

  def self.log10(numeric)
    C.log10(numeric.to_d)
  end

  def self.log2(numeric)
    C.log2(numeric.to_d)
  end

  def self.min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def self.max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  def self.sin(value)
    C.sin(value.to_d)
  end

  def self.sinh(value)
    C.sinh(value.to_d)
  end

  def self.tan(value)
    C.tan(value.to_d)
  end

  def self.tanh(value)
    C.tanh(value.to_d)
  end

  def self.sqrt(value : Int)
    sqrt value.to_d
  end
end