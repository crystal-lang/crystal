require "./libm"

module Math
  extend self

  PI    = 3.14159265358979323846
  E     = LibM.exp_f64(1.0)
  LOG2  = LibM.log_f64(2.0)
  LOG10 = LibM.log_f64(10.0)

  {% for name in %w(acos acosh asin asinh atan atanh cbrt cos cosh erf erfc exp
                   exp2 expm1 ilogb log log10 log1p log2 logb sin sinh sqrt tan tanh) %}
    # Calculates the {{name.id}} of *value*.
    def {{name.id}}(value : Float32)
      LibM.{{name.id}}_f32(value)
    end

    # ditto
    def {{name.id}}(value : Float64)
      LibM.{{name.id}}_f64(value)
    end

    # ditto
    def {{name.id}}(value)
      {{name.id}}(value.to_f)
    end
  {% end %}

  {% for name in %w(besselj0 besselj1 bessely0 bessely1) %}
    # Calculates the {{name.id}} function of *value*.
    def {{name.id}}(value : Float32)
      {% if flag?(:darwin) %}
        LibM.{{name.id}}_f64(value).to_f32
      {% else %}
        LibM.{{name.id}}_f32(value)
      {% end %}
    end

    # ditto
    def {{name.id}}(value : Float64)
      LibM.{{name.id}}_f64(value)
    end

    # ditto
    def {{name.id}}(value)
      {{name.id}}(value.to_f)
    end
  {% end %}

  # Calculates the gamma function of *value*.
  #
  # Note that `gamma(n)` is same as `fact(n - 1)` for integer `n > 0`.
  # However `gamma(n)` returns float and can be an approximation.
  def gamma(value : Float32)
    LibM.tgamma_f32(value)
  end

  # ditto
  def gamma(value : Float64)
    LibM.tgamma_f64(value)
  end

  # ditto
  def gamma(value)
    gamma(value.to_f)
  end

  # Calculates the logarithmic gamma of *value*.
  #
  # ```
  # Math.lgamma(2.96)
  # ```
  # is the same as
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

  # ditto
  def lgamma(value : Float64)
    LibM.gamma_f64(value)
  end

  # ditto
  def lgamma(value)
    lgamma(value.to_f)
  end

  {% for name in %w(atan2 copysign hypot) %}
    # Calculates {{name.id}} with parameters *value1* and *value2*.
    def {{name.id}}(value1 : Float32, value2 : Float32)
      LibM.{{name.id}}_f32(value1, value2)
    end

    # ditto
    def {{name.id}}(value1 : Float64, value2 : Float64)
      LibM.{{name.id}}_f64(value1, value2)
    end

    # ditto
    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_f, value2.to_f)
    end
  {% end %}

  # ## To be uncommented once LLVM is updated
  # def div(value1 : Int32, value2 : Int32)
  #   LibM.div_i32(value1, value2)
  # end
  #
  # def div(value1 : Float32, value2 : Float32)
  #   LibM.div_f32(value1, value2)
  # end
  #
  # def div(value1 : Float64, value2 : Float64)
  #   LibM.div_f64(value1, value2)
  # end
  #
  # def div(value1, value2)
  #   LibM.div(value1, value2)
  # end

  # Returns the logarithm of *numeric* to the base *base*.
  def log(numeric, base)
    log(numeric) / log(base)
  end

  def max(value1 : Float32, value2 : Float32)
    LibM.max_f32(value1, value2)
  end

  def max(value1 : Float64, value2 : Float64)
    LibM.max_f64(value1, value2)
  end

  # Returns the greater of *value1* and *value2*.
  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  def min(value1 : Float32, value2 : Float32)
    LibM.min_f32(value1, value2)
  end

  def min(value1 : Float64, value2 : Float64)
    LibM.min_f64(value1, value2)
  end

  # Returns the smaller of *value1* and *value2*.
  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  # ## To be uncommented once LLVM is updated
  # def rem(value1 : Int32, value2 : Int32)
  #   LibM.rem_i32(value1, value2)
  # end

  # def rem(value1 : Float32, value2 : Float32)
  #   LibM.rem_f32(value1, value2)
  # end

  # def rem(value1 : Float64, value2 : Float64)
  #   LibM.rem_f64(value1, value2)
  # end

  # def rem(value1, value2)
  #   LibM.rem(value1, value2)
  # end

  {% for name in %w(besselj bessely) %}
    # Calculates {{name.id}} with parameters *value1* and *value2*.
    def {{name.id}}(value1 : Int32, value2 : Float32)
      {% if flag?(:darwin) %}
        LibM.{{name.id}}_f64(value1, value2).to_f32
      {% else %}
        LibM.{{name.id}}_f32(value1, value2)
      {% end %}
    end

    # ditto
    def {{name.id}}(value1 : Int32, value2 : Float64)
      LibM.{{name.id}}_f64(value1, value2)
    end

    # ditto
    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_i32, value1.to_f)
    end
  {% end %}

  {% for name in %w(ldexp scalbn) %}
    # Calculates {{name.id}} with parameters *value1* and *value2*.
    def {{name.id}}(value1 : Float32, value2 : Int32)
      LibM.{{name.id}}_f32(value1, value2)
    end

    # ditto
    def {{name.id}}(value1 : Float64, value2 : Int32)
      LibM.{{name.id}}_f64(value1, value2)
    end

    # ditto
    def {{name.id}}(value1, value2)
      {{name.id}}(value1.to_f, value2.to_i32)
    end
  {% end %}

  # Multiplies *value* by 2 raised to power *exp*.
  def scalbln(value : Float32, exp : Int64)
    LibM.scalbln_f32(value, exp)
  end

  # ditto
  def scalbln(value : Float64, exp : Int64)
    LibM.scalbln_f64(value, exp)
  end

  # ditto
  def scalbln(value, exp)
    scalbln(value.to_f, exp.to_i64)
  end

  # Decomposes given floating point *value* into a normalized fraction and an integral power of two.
  def frexp(value : Float32)
    frac = LibM.frexp_f32(value, out exp)
    {frac, exp}
  end

  # ditto
  def frexp(value : Float64)
    frac = LibM.frexp_f64(value, out exp)
    {frac, exp}
  end

  # ditto
  def frexp(value)
    frexp(value.to_f)
  end

  # Computes the next highest power of 2 of *v*.
  #
  # ```
  # Math.pw2ceil(33) # => 64
  # ```
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
