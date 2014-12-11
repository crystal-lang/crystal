require "./libm"
require "./stats"

module Math
  extend self

  PI = 3.14159265358979323846
  E = LibM.exp_f64(1.0)
  LOG2 = LibM.log_f64(2.0)
  LOG10 = LibM.log_f64(10.0)

  {% for name in %w(acos acosh asin asinh atan atanh cbrt cos cosh erf erfc exp
    exp2 expm1 ilogb log log10 log1p log2 logb sin sinh sqrt tan tanh) %}
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

  {% for name in %w(besselj0 besselj1 bessely0 bessely1) %}
    def {{name.id}}(value : Float32)
      {{:ifdef.id}} darwin
        LibM.{{name.id}}_f64(value.to_f64).to_f32
      else
        LibM.{{name.id}}_f32(value)
      {{:end.id}}
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
    ifdef darwin
      LibM.gamma_f64(value.to_f64).to_f32
    else
      LibM.gamma_f32(value)
    end
  end

  def lgamma(value : Float64)
    LibM.gamma_f64(value)
  end

  def lgamma(value)
    LibM.gamma(value.to_f)
  end

  {% for name in %w(atan2 copysign hypot) %}
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

  ### To be uncommented once LLVM is updated
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
  #   LibM.div(value1.to_f, value2.to_f)
  # end

  def log(numeric, base)
    log(numeric) / log(base)
  end

  ### To be uncommented once LLVM is updated
  # def max(value1 : Float32, value2 : Float32)
  #   LibM.max_f32(value1, value2)
  # end
  #
  # def max(value1 : Float64, value2 : Float64)
  #   LibM.max_f64(value1, value2)
  # end

  def max(value1, value2)
    value1 >= value2 ? value1 : value2
  end

  ### To be uncommented once LLVM is updated
  #def min(value1 : Float32, value2 : Float32)
  #  LibM.min_f32(value1, value2)
  #end
  #
  #def min(value1 : Float64, value2 : Float64)
  #  LibM.min_f64(value1, value2)
  #end

  def min(value1, value2)
    value1 <= value2 ? value1 : value2
  end

  ### To be uncommented once LLVM is updated
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
  #   LibM.rem(value1.to_f, value2.to_f)
  # end

  {% for name in %w(besselj bessely) %}
    def {{name.id}}(value1 : Int32, value2 : Float32)
      {{:ifdef.id}} darwin
        LibM.{{name.id}}_f64(value1, value2.to_f64).to_f32
      else
        LibM.{{name.id}}_f32(value1, value2)
      {{:end.id}}
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
