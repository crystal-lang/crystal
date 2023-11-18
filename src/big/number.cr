struct BigInt
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigFloat
  Number.expand_div [Float32, Float64], BigFloat
end

struct BigFloat
  def fdiv(other : Number::Primitive) : self
    self.class.new(self / other)
  end

  def /(other : Int::Primitive) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0
    Int.primitive_ui_check(other) do |ui, neg_ui, _|
      {
        ui:     BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, {{ ui }}) },
        neg_ui: BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, {{ neg_ui }}); LibGMP.mpf_neg(mpf, mpf) },
        big_i:  BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, BigFloat.new(other)) },
      }
    end
  end

  Number.expand_div [Float32, Float64], BigFloat
end

struct BigDecimal
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigDecimal
  Number.expand_div [Float32, Float64], BigDecimal
end

struct BigRational
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigRational
  Number.expand_div [Float32, Float64], BigRational
end

struct Int
  # :nodoc:
  # Yields 3 expressions: `Call`s nodes that convert *var* into a `LibGMP::SI`,
  # a `LibGMP::UI`, and a `BigInt` respectively. These expressions are not
  # evaluated unless they are interpolated in *block*.
  #
  # *block* should return a named tuple: the value for `:si` is returned by the
  # macro if *var* fits into a `LibGMP::SI`, the value for `:ui` returned if
  # *var* fits into a `LibGMP::UI`, and the value for `:big_i` otherwise.
  macro primitive_si_ui_check(var, &block)
    {%
      exps = yield(
        "::LibGMP::SI.new!(#{var.id})".id,
        "::LibGMP::UI.new!(#{var.id})".id,
        "::BigInt.new(#{var.id})".id,
      )
    %}
    if ::LibGMP::SI::MIN <= {{ var }} <= ::LibGMP::UI::MAX
      if {{ var }} <= ::LibGMP::SI::MAX
        {{ exps[:si] }}
      else
        {{ exps[:ui] }}
      end
    else
      {{ exps[:big_i] }}
    end
  end

  # :nodoc:
  # Yields 3 expressions: `Call`s nodes that convert *var* into a `LibGMP::UI`,
  # the negative of *var* into a `LibGMP::UI`, and *var* into a `BigInt`,
  # respectively. These expressions are not evaluated unless they are
  # interpolated in *block*.
  #
  # *block* should return a named tuple: the value for `:ui` is returned by the
  # macro if *var* fits into a `LibGMP::UI`, the value for `:neg_ui` returned if
  # the negative of *var* fits into a `LibGMP::UI`, and the value for `:big_i`
  # otherwise.
  macro primitive_ui_check(var, &block)
    {%
      exps = yield(
        "::LibGMP::UI.new!(#{var.id})".id,
        "::LibGMP::UI.new!((#{var.id}).abs_unsigned)".id,
        "::BigInt.new(#{var.id})".id,
      )
    %}
    if ::LibGMP::UI::MIN <= {{ var }} <= ::LibGMP::UI::MAX
      {{ exps[:ui] }}
    elsif {{ var }}.responds_to?(:abs_unsigned) && {{ var }}.abs_unsigned <= ::LibGMP::UI::MAX
      {{ exps[:neg_ui] }}
    else
      {{ exps[:big_i] }}
    end
  end
end

struct Int8
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Int16
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Int32
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Int64
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Int128
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct UInt8
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct UInt16
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct UInt32
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct UInt64
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct UInt128
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Float
  def fdiv(other : BigInt | BigFloat | BigDecimal | BigRational) : self
    self.class.new(self / other)
  end
end

struct Float32
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end

struct Float64
  Number.expand_div [BigInt], BigFloat
  Number.expand_div [BigFloat], BigFloat
  Number.expand_div [BigDecimal], BigDecimal
  Number.expand_div [BigRational], BigRational
end
