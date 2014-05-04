lib C
  fun acos(x : Float64) : Float64
  fun acosh(x : Float64) : Float64
  fun asin(x : Float64) : Float64
  fun asinh(x : Float64) : Float64
  fun atan(x : Float64) : Float64
  fun atan2(y : Float64, x : Float64) : Float64
  fun cbrt(x : Float64) : Float64
  fun erf(x : Float64) : Float64
  fun erfc(x : Float64) : Float64
  fun hypot(x : Float64, y : Float64) : Float64
  fun ldexp(flt : Float64, int : Int32) : Float64
  fun lgamma(x : Float64) : Float64
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

  E  = Intrinsics.exp_f64(1.0)
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

  def cos(value : Float32)
    Intrinsics.cos_f32(value)
  end

  def cos(value : Float64)
    Intrinsics.cos_f64(value)
  end

  def cos(value)
    cos(value.to_f64)
  end

  def erf(value)
    C.erf(value.to_f64)
  end

  def erfc(value)
    C.erfc(value.to_f64)
  end

  def exp(value : Float32)
    Intrinsics.exp_f32(value)
  end

  def exp(value : Float64)
    Intrinsics.exp_f64(value)
  end

  def exp(value)
    exp(value.to_f64)
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

  def log(value : Float32)
    Intrinsics.log_f32(value)
  end

  def log(value : Float64)
    Intrinsics.log_f64(value)
  end

  def log(value)
    log(value.to_f64)
  end

  def log(numeric, base)
    log(numeric) / log(base)
  end

  def log2(value : Float32)
    Intrinsics.log2_f32(value)
  end

  def log2(value : Float64)
    Intrinsics.log2_f64(value)
  end

  def log2(value)
    log2(value.to_f64)
  end

  def log10(value : Float32)
    Intrinsics.log10_f32(value)
  end

  def log10(value : Float64)
    Intrinsics.log10_f64(value)
  end

  def log10(value)
    log10(value.to_f64)
  end

  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  def sin(value : Float32)
    Intrinsics.sin_f32(value)
  end

  def sin(value : Float64)
    Intrinsics.sin_f64(value)
  end

  def sin(value)
    sin(value.to_f64)
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
