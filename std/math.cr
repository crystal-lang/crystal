lib C
  fun acos(x : Float64) : Float64
  fun acosh(x : Float64) : Float64
  fun asin(x : Float64) : Float64
  fun asinh(x : Float64) : Float64
  fun atan(x : Float64) : Float64
  fun atan2(y : Float64, x : Float64) : Float64
  fun cbrt(x : Float64) : Float64
  fun cos(x : Float64) : Float64
  fun erf(x : Float64) : Float64
  fun erfc(x : Float64) : Float64
  fun exp(x : Float64) : Float64
  fun hypot(x : Float64, y : Float64) : Float64
  fun ldexp(flt : Float64, int : Int32) : Float64
  fun lgamma(x : Float64) : Float64
  fun log(x : Float64) : Float64
  fun log10(x : Float64) : Float64
  fun log2(x : Float64) : Float64
  fun sin(x : Float64) : Float64
  fun sinh(x : Float64) : Float64
  fun tan(x : Float64) : Float64
  fun tanh(x : Float64) : Float64
  fun tgamma(x : Float64) : Float64
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