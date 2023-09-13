# MUSL: On musl systems, libm is empty. The entire library is already included in libc.
# The empty library is only available for POSIX compatibility. We don't need to link it.
#
# Interpreter: On GNU systems, libm.so is typically a GNU ld script which adds
# the actual library file to the load path. `Crystal::Loader` does not support
# ld scripts yet. So we just skip that for now. The libm symbols are still
# available in the interpreter.
{% if (flag?(:linux) && !flag?(:musl) && !flag?(:interpreted)) || flag?(:bsd) %}
  @[Link("m")]
{% end %}

lib LibM
  # LLVM standard C library intrinsics
  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_ceil_f32)] {% end %}
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_ceil_f64)] {% end %}
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_copysign_f32)] {% end %}
  fun copysign_f32 = "llvm.copysign.f32"(magnitude : Float32, sign : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_copysign_f64)] {% end %}
  fun copysign_f64 = "llvm.copysign.f64"(magnitude : Float64, sign : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_cos_f32)] {% end %}
  fun cos_f32 = "llvm.cos.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_cos_f64)] {% end %}
  fun cos_f64 = "llvm.cos.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_exp_f32)] {% end %}
  fun exp_f32 = "llvm.exp.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_exp_f64)] {% end %}
  fun exp_f64 = "llvm.exp.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_exp2_f32)] {% end %}
  fun exp2_f32 = "llvm.exp2.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_exp2_f64)] {% end %}
  fun exp2_f64 = "llvm.exp2.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_floor_f32)] {% end %}
  fun floor_f32 = "llvm.floor.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_floor_f64)] {% end %}
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log_f32)] {% end %}
  fun log_f32 = "llvm.log.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log_f64)] {% end %}
  fun log_f64 = "llvm.log.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log2_f32)] {% end %}
  fun log2_f32 = "llvm.log2.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log2_f64)] {% end %}
  fun log2_f64 = "llvm.log2.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log10_f32)] {% end %}
  fun log10_f32 = "llvm.log10.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_log10_f64)] {% end %}
  fun log10_f64 = "llvm.log10.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_min_f32)] {% end %}
  fun min_f32 = "llvm.minnum.f32"(value1 : Float32, value2 : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_min_f64)] {% end %}
  fun min_f64 = "llvm.minnum.f64"(value1 : Float64, value2 : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_max_f32)] {% end %}
  fun max_f32 = "llvm.maxnum.f32"(value1 : Float32, value2 : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_max_f64)] {% end %}
  fun max_f64 = "llvm.maxnum.f64"(value1 : Float64, value2 : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_pow_f32)] {% end %}
  fun pow_f32 = "llvm.pow.f32"(value : Float32, power : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_pow_f64)] {% end %}
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64

  {% if flag?(:win32) %}
  {% elsif flag?(:interpreted) %}
    @[Primitive(:interpreter_libm_powi_f32)]
    fun powi_f32 = "llvm.powi.f32"(value : Float32, power : Int32) : Float32

    @[Primitive(:interpreter_libm_powi_f64)]
    fun powi_f64 = "llvm.powi.f64"(value : Float64, power : Int32) : Float64
  {% elsif compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %}
    fun powi_f32 = "llvm.powi.f32"(value : Float32, power : Int32) : Float32
    fun powi_f64 = "llvm.powi.f64"(value : Float64, power : Int32) : Float64
  {% else %}
    fun powi_f32 = "llvm.powi.f32.i32"(value : Float32, power : Int32) : Float32
    fun powi_f64 = "llvm.powi.f64.i32"(value : Float64, power : Int32) : Float64
  {% end %}

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_round_f32)] {% end %}
  fun round_f32 = "llvm.round.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_round_f64)] {% end %}
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_rint_f32)] {% end %}
  fun rint_f32 = "llvm.rint.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_rint_f64)] {% end %}
  fun rint_f64 = "llvm.rint.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_sin_f32)] {% end %}
  fun sin_f32 = "llvm.sin.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_sin_f64)] {% end %}
  fun sin_f64 = "llvm.sin.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_sqrt_f32)] {% end %}
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_sqrt_f64)] {% end %}
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_trunc_f32)] {% end %}
  fun trunc_f32 = "llvm.trunc.f32"(value : Float32) : Float32

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_libm_trunc_f64)] {% end %}
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
  {% if flag?(:win32) %}
    fun besselj0_f64 = _j0(value : Float64) : Float64
    fun besselj1_f64 = _j1(value : Float64) : Float64
    fun besselj_f64 = _jn(value1 : Int32, value2 : Float64) : Float64
    fun bessely0_f64 = _y0(value : Float64) : Float64
    fun bessely1_f64 = _y1(value : Float64) : Float64
    fun bessely_f64 = _yn(value1 : Int32, value2 : Float64) : Float64
  {% else %}
    fun besselj0_f32 = j0f(value : Float32) : Float32
    fun besselj0_f64 = j0(value : Float64) : Float64
    fun besselj1_f32 = j1f(value : Float32) : Float32
    fun besselj1_f64 = j1(value : Float64) : Float64
    fun besselj_f32 = jnf(value1 : Int32, value2 : Float32) : Float32
    fun besselj_f64 = jn(value1 : Int32, value2 : Float64) : Float64
    fun bessely0_f32 = y0f(value : Float32) : Float32
    fun bessely0_f64 = y0(value : Float64) : Float64
    fun bessely1_f32 = y1f(value : Float32) : Float32
    fun bessely1_f64 = y1(value : Float64) : Float64
    fun bessely_f32 = ynf(value1 : Int32, value2 : Float32) : Float32
    fun bessely_f64 = yn(value1 : Int32, value2 : Float64) : Float64
  {% end %}
  fun cbrt_f32 = cbrtf(value : Float32) : Float32
  fun cbrt_f64 = cbrt(value : Float64) : Float64
  fun cosh_f32 = coshf(value : Float32) : Float32
  fun cosh_f64 = cosh(value : Float64) : Float64
  fun erfc_f32 = erfcf(value : Float32) : Float32
  fun erfc_f64 = erfc(value : Float64) : Float64
  fun erf_f32 = erff(value : Float32) : Float32
  fun erf_f64 = erf(value : Float64) : Float64
  fun expm1_f32 = expm1f(value : Float32) : Float32
  fun expm1_f64 = expm1(value : Float64) : Float64
  {% unless flag?(:win32) %}
    fun frexp_f32 = frexpf(value : Float32, exp : Int32*) : Float32
  {% end %}
  fun frexp_f64 = frexp(value : Float64, exp : Int32*) : Float64
  fun gamma_f32 = lgammaf(value : Float32) : Float32
  fun gamma_f64 = lgamma(value : Float64) : Float64
  {% if flag?(:win32) %}
    fun hypot_f32 = _hypotf(value1 : Float32, value2 : Float32) : Float32
  {% else %}
    fun hypot_f32 = hypotf(value1 : Float32, value2 : Float32) : Float32
  {% end %}
  fun hypot_f64 = hypot(value1 : Float64, value2 : Float64) : Float64
  fun ilogb_f32 = ilogbf(value : Float32) : Int32
  fun ilogb_f64 = ilogb(value : Float64) : Int32
  {% unless flag?(:win32) %}
    fun ldexp_f32 = ldexpf(value1 : Float32, value2 : Int32) : Float32
  {% end %}
  fun ldexp_f64 = ldexp(value1 : Float64, value2 : Int32) : Float64
  fun log1p_f32 = log1pf(value : Float32) : Float32
  fun log1p_f64 = log1p(value : Float64) : Float64
  fun logb_f32 = logbf(value : Float32) : Float32
  fun logb_f64 = logb(value : Float64) : Float64
  fun nextafter_f32 = nextafterf(from : Float32, to : Float32) : Float32
  fun nextafter_f64 = nextafter(from : Float64, to : Float64) : Float64
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
end
