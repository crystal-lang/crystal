@[Link("m")] ifdef linux
lib LibM
  # LLVM binary operations
  fun div_i32 = "llvm.sdiv"(value1 : Int32, value2 : Int32) : Int32
  fun div_f32 = "llvm.fdiv"(value1 : Float32, value2 : Float32) : Float32
  fun div_f64 = "llvm.fdiv"(value1 : Float64, value2 : Float64) : Float64
  fun rem_i32 = "llvm.srem"(value1 : Int32, value2 : Int32) : Int32
  fun rem_f32 = "llvm.frem"(value1 : Float32, value2 : Float32) : Float32
  fun rem_f64 = "llvm.frem"(value1 : Float64, value2 : Float64) : Float64

  # LLVM standard C library intrinsics
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun copysign_f32 = "llvm.copysign.f32"(magnitude : Float32, sign : Float32) : Float32
  fun copysign_f64 = "llvm.copysign.f64"(magnitude : Float64, sign : Float64) : Float64
  fun cos_f32 = "llvm.cos.f32"(value : Float32) : Float32
  fun cos_f64 = "llvm.cos.f64"(value : Float64) : Float64
  fun exp_f32 = "llvm.exp.f32"(value : Float32) : Float32
  fun exp_f64 = "llvm.exp.f64"(value : Float64) : Float64
  fun floor_f32 = "llvm.floor.f32"(value : Float32) : Float32
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun log_f32 = "llvm.log.f32"(value : Float32) : Float32
  fun log_f64 = "llvm.log.f64"(value : Float64) : Float64
  fun log2_f32 = "llvm.log2.f32"(value : Float32) : Float32
  fun log2_f64 = "llvm.log2.f64"(value : Float64) : Float64
  fun log10_f32 = "llvm.log10.f32"(value : Float32) : Float32
  fun log10_f64 = "llvm.log10.f64"(value : Float64) : Float64
  fun min_f32 = "llvm.minnum.f32"(value1 : Float32, value2 : Float32) : Float32
  fun min_f64 = "llvm.minnum.f64"(value1 : Float64, value2 : Float64) : Float64
  fun max_f32 = "llvm.maxnum.f32"(value1 : Float32, value2 : Float32) : Float32
  fun max_f64 = "llvm.maxnum.f64"(value1 : Float64, value2 : Float64) : Float64
  fun pow_f32 = "llvm.pow.f32"(value : Float32, power : Float32) : Float32
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun powi_f32 = "llvm.powi.f32"(value : Float32, power : Int32) : Float32
  fun powi_f64 = "llvm.powi.f64"(value : Float64, power : Int32) : Float64
  fun round_f32 = "llvm.round.f32"(value : Float32) : Float32
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
  fun sin_f32 = "llvm.sin.f32"(value : Float32) : Float32
  fun sin_f64 = "llvm.sin.f64"(value : Float64) : Float64
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64
  fun trunc_f32 = "llvm.trunc.f32"(value : Float32) : Float32
  fun trunc_f64 = "llvm.trunc.f64"(value : Float64) : Float64

  # libm functions
  fun acos_f32 = acosf(value : Float32) : Float32
  fun acos_f64 = acos(value : Float64) : Float64
  fun acosh_f32 = acoshf(value : Float32) : Float32
  fun acosh_f64 = acosh(value : Float64) : Float64
  fun asin_f32 = asinf(value : Float32) : Float32
  fun asin_f64 = asin(value : Float64) : Float64
  fun asinh_f32 = asinhf(value : Float32) : Float32
  fun asinh_f64 = asinh(value : Float64) : Float64
  fun atan2_f32 = atan2f(value1 : Float32, value2 : Float32) : Float32
  fun atan2_f64 = atan2(value1 : Float64, value2 : Float64) : Float64
  fun atan_f32 = atanf(value : Float32) : Float32
  fun atan_f64 = atan(value : Float64) : Float64
  fun atanh_f32 = atanhf(value : Float32) : Float32
  fun atanh_f64 = atanh(value : Float64) : Float64
  fun cbrt_f32 = cbrtf(value : Float32) : Float32
  fun cbrt_f64 = cbrt(value : Float64) : Float64
  fun cosh_f32 = coshf(value : Float32) : Float32
  fun cosh_f64 = cosh(value : Float64) : Float64
  fun erfc_f32 = erfcf(value : Float32) : Float32
  fun erfc_f64 = erfc(value : Float64) : Float64
  fun erf_f32 = erff(value : Float32) : Float32
  fun erf_f64 = erf(value : Float64) : Float64
  fun exp2_f32 = exp2f(value : Float32) : Float32
  fun exp2_f64 = exp2(value : Float64) : Float64
  fun expm1_f32 = expm1f(value : Float32) : Float32
  fun expm1_f64 = expm1(value : Float64) : Float64
  fun fdim_f32 = fdimf(value1 : Float32, value2 : Float32) : Float32
  fun fdim_f64 = fdim(value1 : Float64, value2 : Float64) : Float64
  fun fma_f32 = fmaf(value1 : Float32, value2 : Float32, value3 : Float32) : Float32
  fun fma_f64 = fma(value1 : Float64, value2 : Float64, value3 : Float64) : Float64
  fun gamma_f32 = gammaf(value : Float32) : Float32
  fun gamma_f64 = gamma(value : Float64) : Float64
  fun hypot_f32 = hypotf(value1 : Float32, value2 : Float32) : Float32
  fun hypot_f64 = hypot(value1 : Float64, value2 : Float64) : Float64
  fun ilogb_f32 = ilogbf(value : Float32) : Float32
  fun ilogb_f64 = ilogb(value : Float64) : Float64
  fun j0_f32 = j0f(value : Float32) : Float32
  fun j0_f64 = j0(value : Float64) : Float64
  fun j1_f32 = j1f(value : Float32) : Float32
  fun j1_f64 = j1(value : Float64) : Float64
  fun jn_f32 = jnf(value1 : Int32, value2 : Float32) : Float32
  fun jn_f64 = jn(value1 : Int32, value2 : Float64) : Float64
  fun ldexp_f32 = ldexpf(value1 : Float32, value2 : Int32) : Float32
  fun ldexp_f64 = ldexp(value1 : Float64, value2 : Int32) : Float64
  fun log1p_f32 = log1pf(value : Float32) : Float32
  fun log1p_f64 = log1p(value : Float64) : Float64
  fun logb_f32 = logbf(value : Float32) : Float32
  fun logb_f64 = logb(value : Float64) : Float64
  fun nextafter_f32 = nextafterf(value1 : Float32, value2 : Float32) : Float32
  fun nextafter_f64 = nextafter(value1 : Float64, value2 : Float64) : Float64
  fun scalbln_f32 = scalblnf(value1 : Float32, value2 : Int64) : Float32
  fun scalbln_f64 = scalbln(value1 : Float64, value2 : Int64) : Float64
  fun scalbn_f32 = scalbnf(value1 : Float32, value2 : Int32) : Float32
  fun scalbn_f64 = scalbn(value1 : Float64, value2 : Int32) : Float64
  fun sinh_f32 = sinhf(value : Float32) : Float32
  fun sinh_f64 = sinh(value : Float64) : Float64
  fun tan_f32 = tanf(value : Float32) : Float32
  fun tan_f64 = tan(value : Float64) : Float64
  fun tanh_f32 = tanhf(value : Float32) : Float32
  fun tanh_f64 = tanh(value : Float64) : Float64
  fun tgamma_f32 = tgammaf(value : Float32) : Float32
  fun tgamma_f64 = tgamma(value : Float64) : Float64
  fun y0_f32 = y0f(value : Float32) : Float32
  fun y0_f64 = y0(value : Float64) : Float64
  fun y1_f32 = y1f(value : Float32) : Float32
  fun y1_f64 = y1(value : Float64) : Float64
  fun yn_f32 = ynf(value1 : Int32, value2 : Float32) : Float32
  fun yn_f64 = yn(value1 : Int32, value2 : Float64) : Float64
end

module Math
  extend self

  PI = 3.14159265358979323846
  E = LibM.exp_f64(1.0)
  LOG2 = LibM.log_f64(2.0)
  LOG10 = LibM.log_f64(10.0)

  {% for name in %w(acos acosh asin asinh atan atanh cbrt cos cosh erf erfc exp exp2 expm1 ilogb j0 j1 log log10 log1p
    log2 logb min max sin sinh sqrt tan tanh y0 y1) %}
    def {{name.id}}(value : Float32)
      LibM.{{name.id}}_f32(value)
    end

    def {{name.id}}(value : Float64)
      LibM.{{name.id}}_f64(value)
    end

    def {{name.id}}(value)
      {{name.id}}(value.to_f)
    end
  {% end %}

  def gamma(value : Float32)
    LibM.tgamma_f32(value)
  end

  def gamma(value : Float64)
    LibM.tgamma_f64(value)
  end

  def gamma(value)
    LibM.tgamma(value.to_f)
  end

  def lgamma(value : Float32)
    LibM.gamma_f32(value)
  end

  def lgamma(value : Float64)
    LibM.gamma_f64(value)
  end

  def lgamma(value)
    LibM.gamma(value.to_f)
  end

  {% for name in %w(atan2 copysign fdim fmod hypot nextafter remainder) %}
    def {{name.id}}(value1 : Float32, value2 : Float32)
      LibM.{{name.id}}_f32(value1, value2)
    end

    def {{name.id}}(value1 : Float64, value2 : Float64)
      LibM.{{name.id}}_f64(value1, value2)
    end

    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_f, value1.to_f)
    end
  {% end %}

  def div(value1 : Int32, value2 : Int32)
    LibM.div_i32(value1, value2)
  end

  def div(value1 : Float32, value2 : Float32)
    LibM.div_f32(value1, value2)
  end

  def div(value1 : Float64, value2 : Float64)
    LibM.div_f64(value1, value2)
  end

  def div(value1, value2)
    LibM.div(value1.to_f, value2.to_f)
  end

  def max(value1 : Float32, value2 : Float32)
    LibM.max_f32(value1, value2)
  end

  def max(value1 : Float64, value2 : Float64)
    LibM.max_f64(value1, value2)
  end

  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  def min(value1 : Float32, value2 : Float32)
    LibM.min_f32(value1, value2)
  end

  def min(value1 : Float64, value2 : Float64)
    LibM.min_f64(value1, value2)
  end

  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def rem(value1 : Int32, value2 : Int32)
    LibM.rem_i32(value1, value2)
  end

  def rem(value1 : Float32, value2 : Float32)
    LibM.rem_f32(value1, value2)
  end

  def rem(value1 : Float64, value2 : Float64)
    LibM.rem_f64(value1, value2)
  end

  def rem(value1, value2)
    LibM.rem(value1.to_f, value2.to_f)
  end

  {% for name in %w(jn yn) %}
    def {{name.id}}(value1 : Int32, value2 : Float32)
      LibM.{{name.id}}_f32(value1, value2)
    end

    def {{name.id}}(value1 : Int32, value2 : Float64)
      LibM.{{name.id}}_f64(value1, value2)
    end

    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_i32, value1.to_f)
    end
  {% end %}

  {% for name in %w(ldexp scalbn) %}
    def {{name.id}}(value1 : Float32, value2 : Int32)
      LibM.{{name.id}}_f32(value1, value2)
    end

    def {{name.id}}(value1 : Float64, value2 : Int32)
      LibM.{{name.id}}_f64(value1, value2)
    end

    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_f, value2.to_i32)
    end
  {% end %}

  def scalbln(value1 : Float32, value2 : Int64)
    LibM.scalbln_f32(value1, value2)
  end

  def scalbln(value1 : Float64, value2 : Int64)
    LibM.scalbln_f64(value1, value2)
  end

  def scalbln(value1, value2)
    scalbln(value1.to_f, value2.to_i64)
  end

  def fma(value1 : Float32, value2 : Float32, value3 : Float32)
    LibM.fma_f32(value1, value2, value3)
  end

  def fma(value1 : Float64, value2 : Float64, value3 : Float64)
    LibM.fma_f64(value1, value2, value3)
  end

  def fma(value1, value2, value3)
    fma(value1.to_f, value1.to_f, value3.to_f)
  end

  def log(numeric, base)
    log(numeric) / log(base)
  end

  def min(value1 : Float)
  end

  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  def max(value1, value2)
    value1 >= value2 ? value1 : value2
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
