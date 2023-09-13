require "./libm"

module Math
  extend self

  # Archimedes' constant (π).
  PI = 3.14159265358979323846
  # The full circle constant (τ), equal to 2π.
  TAU = 6.283185307179586476925
  # Euler's number (e).
  E     = LibM.exp_f64(1.0)
  LOG2  = LibM.log_f64(2.0)
  LOG10 = LibM.log_f64(10.0)

  # Calculates the sine of *value*, measured in radians.
  def sin(value : Float32) : Float32
    LibM.sin_f32(value)
  end

  # :ditto:
  def sin(value : Float64) : Float64
    LibM.sin_f64(value)
  end

  # :ditto:
  def sin(value)
    sin(value.to_f)
  end

  # Calculates the cosine of *value*, measured in radians.
  def cos(value : Float32) : Float32
    LibM.cos_f32(value)
  end

  # :ditto:
  def cos(value : Float64) : Float64
    LibM.cos_f64(value)
  end

  # :ditto:
  def cos(value)
    cos(value.to_f)
  end

  # Calculates the tangent of *value*, measured in radians.
  def tan(value : Float32) : Float32
    LibM.tan_f32(value)
  end

  # :ditto:
  def tan(value : Float64) : Float64
    LibM.tan_f64(value)
  end

  # :ditto:
  def tan(value)
    tan(value.to_f)
  end

  # Calculates the arc sine of *value*.
  def asin(value : Float32) : Float32
    LibM.asin_f32(value)
  end

  # :ditto:
  def asin(value : Float64) : Float64
    LibM.asin_f64(value)
  end

  # :ditto:
  def asin(value)
    asin(value.to_f)
  end

  # Calculates the arc cosine of *value*.
  def acos(value : Float32) : Float32
    LibM.acos_f32(value)
  end

  # :ditto:
  def acos(value : Float64) : Float64
    LibM.acos_f64(value)
  end

  # :ditto:
  def acos(value)
    acos(value.to_f)
  end

  # Calculates the arc tangent of *value*.
  def atan(value : Float32) : Float32
    LibM.atan_f32(value)
  end

  # :ditto:
  def atan(value : Float64) : Float64
    LibM.atan_f64(value)
  end

  # :ditto:
  def atan(value)
    atan(value.to_f)
  end

  # Calculates the two-argument arc tangent of the ray from (0, 0) to (*x*, *y*).
  def atan2(y : Float32, x : Float32) : Float32
    LibM.atan2_f32(y, x)
  end

  # :ditto:
  def atan2(y : Float64, x : Float64) : Float64
    LibM.atan2_f64(y, x)
  end

  # :ditto:
  def atan2(y, x) : Float64
    atan2(y.to_f, x.to_f)
  end

  # Calculates the hyperbolic sine of *value*.
  def sinh(value : Float32) : Float32
    LibM.sinh_f32(value)
  end

  # :ditto:
  def sinh(value : Float64) : Float64
    LibM.sinh_f64(value)
  end

  # :ditto:
  def sinh(value)
    sinh(value.to_f)
  end

  # Calculates the hyperbolic cosine of *value*.
  def cosh(value : Float32) : Float32
    LibM.cosh_f32(value)
  end

  # :ditto:
  def cosh(value : Float64) : Float64
    LibM.cosh_f64(value)
  end

  # :ditto:
  def cosh(value)
    cosh(value.to_f)
  end

  # Calculates the hyperbolic tangent of *value*.
  def tanh(value : Float32) : Float32
    LibM.tanh_f32(value)
  end

  # :ditto:
  def tanh(value : Float64) : Float64
    LibM.tanh_f64(value)
  end

  # :ditto:
  def tanh(value)
    tanh(value.to_f)
  end

  # Calculates the inverse hyperbolic sine of *value*.
  def asinh(value : Float32) : Float32
    LibM.asinh_f32(value)
  end

  # :ditto:
  def asinh(value : Float64) : Float64
    LibM.asinh_f64(value)
  end

  # :ditto:
  def asinh(value)
    asinh(value.to_f)
  end

  # Calculates the inverse hyperbolic cosine of *value*.
  def acosh(value : Float32) : Float32
    LibM.acosh_f32(value)
  end

  # :ditto:
  def acosh(value : Float64) : Float64
    LibM.acosh_f64(value)
  end

  # :ditto:
  def acosh(value)
    acosh(value.to_f)
  end

  # Calculates the inverse hyperbolic tangent of *value*.
  def atanh(value : Float32) : Float32
    LibM.atanh_f32(value)
  end

  # :ditto:
  def atanh(value : Float64) : Float64
    LibM.atanh_f64(value)
  end

  # :ditto:
  def atanh(value)
    atanh(value.to_f)
  end

  # Calculates the exponential of *value*.
  def exp(value : Float32) : Float32
    LibM.exp_f32(value)
  end

  # :ditto:
  def exp(value : Float64) : Float64
    LibM.exp_f64(value)
  end

  # :ditto:
  def exp(value)
    exp(value.to_f)
  end

  # Calculates the exponential of *value*, minus 1.
  def expm1(value : Float32) : Float32
    LibM.expm1_f32(value)
  end

  # :ditto:
  def expm1(value : Float64) : Float64
    LibM.expm1_f64(value)
  end

  # :ditto:
  def expm1(value)
    expm1(value.to_f)
  end

  # Calculates 2 raised to the power *value*.
  def exp2(value : Float32) : Float32
    LibM.exp2_f32(value)
  end

  # :ditto:
  def exp2(value : Float64) : Float64
    LibM.exp2_f64(value)
  end

  # :ditto:
  def exp2(value)
    exp2(value.to_f)
  end

  # Calculates the natural logarithm of *value*.
  def log(value : Float32) : Float32
    LibM.log_f32(value)
  end

  # :ditto:
  def log(value : Float64) : Float64
    LibM.log_f64(value)
  end

  # :ditto:
  def log(value) : Float64
    log(value.to_f)
  end

  # Calculates the natural logarithm of 1 plus *value*.
  def log1p(value : Float32) : Float32
    LibM.log1p_f32(value)
  end

  # :ditto:
  def log1p(value : Float64) : Float64
    LibM.log1p_f64(value)
  end

  # :ditto:
  def log1p(value)
    log1p(value.to_f)
  end

  # Calculates the logarithm of *value* to base 2.
  def log2(value : Float32) : Float32
    LibM.log2_f32(value)
  end

  # :ditto:
  def log2(value : Float64) : Float64
    LibM.log2_f64(value)
  end

  # :ditto:
  def log2(value) : Float64
    log2(value.to_f)
  end

  # Calculates the logarithm of *value* to base 10.
  def log10(value : Float32) : Float32
    LibM.log10_f32(value)
  end

  # :ditto:
  def log10(value : Float64) : Float64
    LibM.log10_f64(value)
  end

  # :ditto:
  def log10(value)
    log10(value.to_f)
  end

  # Calculates the logarithm of *value* to the given *base*.
  def log(value, base)
    log(value) / log(base)
  end

  # Calculates the square root of *value*.
  def sqrt(value : Float32) : Float32
    LibM.sqrt_f32(value)
  end

  # :ditto:
  def sqrt(value : Float64) : Float64
    LibM.sqrt_f64(value)
  end

  # :ditto:
  def sqrt(value) : Float64
    sqrt(value.to_f)
  end

  # Calculates the integer square root of *value*.
  def isqrt(value : Int::Primitive)
    raise ArgumentError.new "Input must be non-negative integer" if value < 0
    return value if value < 2
    res = value.class.zero
    bit = res.succ << (res.leading_zeros_count - 2)
    bit >>= value.leading_zeros_count & ~0x3
    while (bit != 0)
      if value >= res + bit
        value -= res + bit
        res = (res >> 1) + bit
      else
        res >>= 1
      end
      bit >>= 2
    end
    res
  end

  # Calculates the cubic root of *value*.
  def cbrt(value : Float32) : Float32
    LibM.cbrt_f32(value)
  end

  # :ditto:
  def cbrt(value : Float64) : Float64
    LibM.cbrt_f64(value)
  end

  # :ditto:
  def cbrt(value)
    cbrt(value.to_f)
  end

  # Calculates the error function of *value*.
  def erf(value : Float32) : Float32
    LibM.erf_f32(value)
  end

  # :ditto:
  def erf(value : Float64) : Float64
    LibM.erf_f64(value)
  end

  # :ditto:
  def erf(value)
    erf(value.to_f)
  end

  # Calculates 1 minus the error function of *value*.
  def erfc(value : Float32) : Float32
    LibM.erfc_f32(value)
  end

  # :ditto:
  def erfc(value : Float64) : Float64
    LibM.erfc_f64(value)
  end

  # :ditto:
  def erfc(value)
    erfc(value.to_f)
  end

  # Calculates the gamma function of *value*.
  #
  # Note that `gamma(n)` is same as `fact(n - 1)` for integer `n > 0`.
  # However `gamma(n)` returns float and can be an approximation.
  def gamma(value : Float32) : Float32
    LibM.tgamma_f32(value)
  end

  # :ditto:
  def gamma(value : Float64) : Float64
    LibM.tgamma_f64(value)
  end

  # :ditto:
  def gamma(value) : Float64
    gamma(value.to_f)
  end

  # Calculates the logarithmic gamma of *value*.
  #
  # ```
  # Math.lgamma(2.96)
  # ```
  # is equivalent to
  # ```
  # Math.log(Math.gamma(2.96).abs)
  # ```
  def lgamma(value : Float32)
    {% if flag?(:darwin) %}
      LibM.gamma_f64(value).to_f32
    {% else %}
      LibM.gamma_f32(value)
    {% end %}
  end

  # :ditto:
  def lgamma(value : Float64) : Float64
    LibM.gamma_f64(value)
  end

  # :ditto:
  def lgamma(value) : Float64
    lgamma(value.to_f)
  end

  # Calculates the cylindrical Bessel function of the first kind of *value* for the given *order*.
  def besselj(order : Int32, value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.besselj_f64(order, value).to_f32
    {% else %}
      LibM.besselj_f32(order, value)
    {% end %}
  end

  # :ditto:
  def besselj(order : Int32, value : Float64) : Float64
    LibM.besselj_f64(order, value)
  end

  # :ditto:
  def besselj(order, value)
    besselj(order.to_i32, value.to_f)
  end

  # Calculates the cylindrical Bessel function of the first kind of *value* for order 0.
  def besselj0(value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.besselj0_f64(value).to_f32
    {% else %}
      LibM.besselj0_f32(value)
    {% end %}
  end

  # :ditto:
  def besselj0(value : Float64) : Float64
    LibM.besselj0_f64(value)
  end

  # :ditto:
  def besselj0(value)
    besselj0(value.to_f)
  end

  # Calculates the cylindrical Bessel function of the first kind of *value* for order 1.
  def besselj1(value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.besselj1_f64(value).to_f32
    {% else %}
      LibM.besselj1_f32(value)
    {% end %}
  end

  # :ditto:
  def besselj1(value : Float64) : Float64
    LibM.besselj1_f64(value)
  end

  # :ditto:
  def besselj1(value)
    besselj1(value.to_f)
  end

  # Calculates the cylindrical Bessel function of the second kind of *value* for the given *order*.
  def bessely(order : Int32, value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.bessely_f64(order, value).to_f32
    {% else %}
      LibM.bessely_f32(order, value)
    {% end %}
  end

  # :ditto:
  def bessely(order : Int32, value : Float64) : Float64
    LibM.bessely_f64(order, value)
  end

  # :ditto:
  def bessely(order, value)
    bessely(order.to_i32, value.to_f)
  end

  # Calculates the cylindrical Bessel function of the second kind of *value* for order 0.
  def bessely0(value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.bessely0_f64(value).to_f32
    {% else %}
      LibM.bessely0_f32(value)
    {% end %}
  end

  # :ditto:
  def bessely0(value : Float64) : Float64
    LibM.bessely0_f64(value)
  end

  # :ditto:
  def bessely0(value)
    bessely0(value.to_f)
  end

  # Calculates the cylindrical Bessel function of the second kind of *value* for order 1.
  def bessely1(value : Float32)
    {% if flag?(:darwin) || flag?(:win32) %}
      LibM.bessely1_f64(value).to_f32
    {% else %}
      LibM.bessely1_f32(value)
    {% end %}
  end

  # :ditto:
  def bessely1(value : Float64) : Float64
    LibM.bessely1_f64(value)
  end

  # :ditto:
  def bessely1(value)
    bessely1(value.to_f)
  end

  # Calculates the length of the hypotenuse from (0, 0) to (*value1*, *value2*).
  #
  # Equivalent to
  # ```
  # Math.sqrt(value1 ** 2 + value2 ** 2)
  # ```
  def hypot(value1 : Float32, value2 : Float32) : Float32
    LibM.hypot_f32(value1, value2)
  end

  # :ditto:
  def hypot(value1 : Float64, value2 : Float64) : Float64
    LibM.hypot_f64(value1, value2)
  end

  # :ditto:
  def hypot(value1, value2)
    hypot(value1.to_f, value2.to_f)
  end

  # Returns the unbiased base 2 exponent of the given floating-point *value*.
  def ilogb(value : Float32) : Int32
    LibM.ilogb_f32(value)
  end

  # :ditto:
  def ilogb(value : Float64) : Int32
    LibM.ilogb_f64(value)
  end

  # :ditto:
  def ilogb(value)
    ilogb(value.to_f)
  end

  # Returns the unbiased radix-independent exponent of the given floating-point *value*.
  #
  # For `Float32` and `Float64` this is equivalent to `ilogb`.
  def logb(value : Float32) : Float32
    LibM.logb_f32(value)
  end

  # :ditto:
  def logb(value : Float64) : Float64
    LibM.logb_f64(value)
  end

  # :ditto:
  def logb(value)
    logb(value.to_f)
  end

  # Multiplies the given floating-point *value* by 2 raised to the power *exp*.
  def ldexp(value : Float32, exp : Int32) : Float32
    {% if flag?(:win32) %}
      # ucrt does not export `ldexpf` and instead defines it like this
      LibM.ldexp_f64(value, exp).to_f32!
    {% else %}
      LibM.ldexp_f32(value, exp)
    {% end %}
  end

  # :ditto:
  def ldexp(value : Float64, exp : Int32) : Float64
    LibM.ldexp_f64(value, exp)
  end

  # :ditto:
  def ldexp(value, exp)
    ldexp(value.to_f, exp.to_i32)
  end

  # Returns the floating-point *value* with its exponent raised by *exp*.
  #
  # For `Float32` and `Float64` this is equivalent to `ldexp`.
  def scalbn(value : Float32, exp : Int32) : Float32
    LibM.scalbn_f32(value, exp)
  end

  # :ditto:
  def scalbn(value : Float64, exp : Int32) : Float64
    LibM.scalbn_f64(value, exp)
  end

  # :ditto:
  def scalbn(value, exp)
    scalbn(value.to_f, exp.to_i32)
  end

  # :ditto:
  def scalbln(value : Float32, exp : Int64)
    LibM.scalbln_f32(value, exp)
  end

  # :ditto:
  def scalbln(value : Float64, exp : Int64) : Float64
    LibM.scalbln_f64(value, exp)
  end

  # :ditto:
  def scalbln(value, exp) : Float64
    scalbln(value.to_f, exp.to_i64)
  end

  # Decomposes the given floating-point *value* into a normalized fraction and an integral power of two.
  def frexp(value : Float32) : {Float32, Int32}
    {% if flag?(:win32) %}
      # ucrt does not export `frexpf` and instead defines it like this
      frac = LibM.frexp_f64(value, out exp)
      {frac.to_f32, exp}
    {% else %}
      frac = LibM.frexp_f32(value, out exp)
      {frac, exp}
    {% end %}
  end

  # :ditto:
  def frexp(value : Float64) : {Float64, Int32}
    frac = LibM.frexp_f64(value, out exp)
    {frac, exp}
  end

  # :ditto:
  def frexp(value)
    frexp(value.to_f)
  end

  # Returns the floating-point value with the magnitude of *value1* and the sign of *value2*.
  def copysign(value1 : Float32, value2 : Float32)
    LibM.copysign_f32(value1, value2)
  end

  # :ditto:
  def copysign(value1 : Float64, value2 : Float64) : Float64
    LibM.copysign_f64(value1, value2)
  end

  # :ditto:
  def copysign(value1, value2)
    copysign(value1.to_f, value2.to_f)
  end

  # Returns the greater of *value1* and *value2*.
  def max(value1 : Float32, value2 : Float32)
    LibM.max_f32(value1, value2)
  end

  # :ditto:
  def max(value1 : Float64, value2 : Float64) : Float64
    LibM.max_f64(value1, value2)
  end

  # :ditto:
  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  # Returns the smaller of *value1* and *value2*.
  def min(value1 : Float32, value2 : Float32)
    LibM.min_f32(value1, value2)
  end

  # :ditto:
  def min(value1 : Float64, value2 : Float64) : Float64
    LibM.min_f64(value1, value2)
  end

  # :ditto:
  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  # Computes the smallest nonnegative power of 2 that is greater than or equal
  # to *v*.
  #
  # The returned value has the same type as the argument. Raises `OverflowError`
  # if the result does not fit into the argument's type.
  #
  # ```
  # Math.pw2ceil(33) # => 64
  # Math.pw2ceil(64) # => 64
  # Math.pw2ceil(-5) # => 1
  # ```
  def pw2ceil(v : Int::Primitive)
    v.next_power_of_two
  end
end
