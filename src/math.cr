@[Link("m")] ifdef linux
lib LibM
  fun acos(x : Float64) : Float64
  fun acosh(x : Float64) : Float64
  fun asin(x : Float64) : Float64
  fun asinh(x : Float64) : Float64
  fun atan(x : Float64) : Float64
  fun atan2(y : Float64, x : Float64) : Float64
  fun cbrt(x : Float64) : Float64
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun cos_f32 = "llvm.cos.f32"(value : Float32) : Float32
  fun cos_f64 = "llvm.cos.f64"(value : Float64) : Float64
  fun erf(x : Float64) : Float64
  fun erfc(x : Float64) : Float64
  fun exp_f32 = "llvm.exp.f32"(value : Float32) : Float32
  fun exp_f64 = "llvm.exp.f64"(value : Float64) : Float64
  fun hypot(x : Float64, y : Float64) : Float64
  fun ldexp(flt : Float64, int : Int32) : Float64
  fun lgamma(x : Float64) : Float64
  fun log_f32 = "llvm.log.f32"(value : Float32) : Float32
  fun log_f64 = "llvm.log.f64"(value : Float64) : Float64
  fun log2_f32 = "llvm.log2.f32"(value : Float32) : Float32
  fun log2_f64 = "llvm.log2.f64"(value : Float64) : Float64
  fun log10_f32 = "llvm.log10.f32"(value : Float32) : Float32
  fun log10_f64 = "llvm.log10.f64"(value : Float64) : Float64
  fun pow_f32 = "llvm.pow.f32"(value : Float32, power : Float32) : Float32
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun sin_f32 = "llvm.sin.f32"(value : Float32) : Float32
  fun sin_f64 = "llvm.sin.f64"(value : Float64) : Float64
  fun sinh(x : Float64) : Float64
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64
  fun tan(x : Float64) : Float64
  fun tanh(x : Float64) : Float64
  fun tgamma(x : Float64) : Float64
end

module Math
  extend self

  E  = LibM.exp_f64(1.0)
  PI = 3.14159265358979323846

  def acos(value)
    LibM.acos(value.to_f64)
  end

  def acosh(value)
    LibM.acosh(value.to_f64)
  end

  def asin(value)
    LibM.asin(value.to_f64)
  end

  def asinh(value)
    LibM.asinh(value.to_f64)
  end

  def atan(value)
    LibM.atan(value.to_f64)
  end

  def atan2(y, x)
    LibM.atan2(y.to_f64, x.to_f64)
  end

  def cbrt(value)
    LibM.cbrt(value.to_f64)
  end

  def cos(value : Float32)
    LibM.cos_f32(value)
  end

  def cos(value : Float64)
    LibM.cos_f64(value)
  end

  def cos(value)
    cos(value.to_f64)
  end

  def erf(value)
    LibM.erf(value.to_f64)
  end

  def erfc(value)
    LibM.erfc(value.to_f64)
  end

  def exp(value : Float32)
    LibM.exp_f32(value)
  end

  def exp(value : Float64)
    LibM.exp_f64(value)
  end

  def exp(value)
    exp(value.to_f64)
  end

  def gamma(value)
    LibM.tgamma(value.to_f64)
  end

  def hypot(x, y)
    LibM.hypot(x.to_f64, y.to_f64)
  end

  def ldexp(flt, int : Int)
    LibM.ldexp(flt.to_f64, int)
  end

  def log(value : Float32)
    LibM.log_f32(value)
  end

  def log(value : Float64)
    LibM.log_f64(value)
  end

  def log(value)
    log(value.to_f64)
  end

  def log(numeric, base)
    log(numeric) / log(base)
  end

  def log2(value : Float32)
    LibM.log2_f32(value)
  end

  def log2(value : Float64)
    LibM.log2_f64(value)
  end

  def log2(value)
    log2(value.to_f64)
  end

  def log10(value : Float32)
    LibM.log10_f32(value)
  end

  def log10(value : Float64)
    LibM.log10_f64(value)
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
    LibM.sin_f32(value)
  end

  def sin(value : Float64)
    LibM.sin_f64(value)
  end

  def sin(value)
    sin(value.to_f64)
  end

  def sinh(value)
    LibM.sinh(value.to_f64)
  end

  def tan(value)
    LibM.tan(value.to_f64)
  end

  def tanh(value)
    LibM.tanh(value.to_f64)
  end

  def sqrt(value : Float32)
    LibM.sqrt_f32(value)
  end

  def sqrt(value : Float64)
    LibM.sqrt_f64(value)
  end

  def sqrt(value : Int)
    sqrt value.to_f64
  end

  def pw2ceil(v)
    # Taken from http://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
    v -= 1
    v |= v >> 1
    v |= v >> 2
    v |= v >> 4
    v |= v >> 8
    v |= v >> 16
    v += 1
  end
end
