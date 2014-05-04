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

ifdef linux
  lib Libm("m"); end
end

module Math
  extend self

  E  = C.exp(1.0)
  PI = 3.14159265358979323846

  def acos(value)
    C.acos(value.to_f64)
  end

  def acosh(value)
    C.acosh(value.to_f64)
  end

  def asin(value)
    C.asin(value.to_f64)
  end

  def asinh(value)
    C.asinh(value.to_f64)
  end

  def atan(value)
    C.atan(value.to_f64)
  end

  def atan2(y, x)
    C.atan2(y.to_f64, x.to_f64)
  end

  def cbrt(value)
    C.cbrt(value.to_f64)
  end

  def cos(value)
    C.cos(value.to_f64)
  end

  def erf(value)
    C.erf(value.to_f64)
  end

  def erfc(value)
    C.erfc(value.to_f64)
  end

  def exp(value)
    C.exp(value.to_f64)
  end

  def gamma(value)
    C.tgamma(value.to_f64)
  end

  def hypot(x, y)
    C.hypot(x.to_f64, y.to_f64)
  end

  def ldexp(flt, int : Int)
    C.ldexp(flt.to_f64, int)
  end

  def log(numeric)
    C.log(numeric.to_f64)
  end

  def log(numeric, base)
    log(numeric) / log(base)
  end

  def log10(numeric)
    C.log10(numeric.to_f64)
  end

  def log2(numeric)
    C.log2(numeric.to_f64)
  end

  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  def sin(value)
    C.sin(value.to_f64)
  end

  def sinh(value)
    C.sinh(value.to_f64)
  end

  def tan(value)
    C.tan(value.to_f64)
  end

  def tanh(value)
    C.tanh(value.to_f64)
  end

  def sqrt(value : Float32)
    Intrinsics.sqrt_f32(value)
  end

  def sqrt(value : Float64)
    Intrinsics.sqrt_f64(value)
  end

  def sqrt(value : Int)
    sqrt value.to_f64
  end
end
