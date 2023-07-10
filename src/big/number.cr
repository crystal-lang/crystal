struct BigInt
  Number.expand_div [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128], BigFloat
  Number.expand_div [Float32, Float64], BigFloat
end

struct BigFloat
  def fdiv(other : Number::Primitive) : self
    self.class.new(self / other)
  end

  def /(other : UInt8 | UInt16 | UInt32 | UInt64) : BigFloat
    # Division by 0 in BigFloat is not allowed, there is no BigFloat::Infinity
    raise DivisionByZeroError.new if other == 0
    if other.is_a?(UInt8 | UInt16 | UInt32) || (LibGMP::ULong == UInt64 && other.is_a?(UInt64))
      BigFloat.new { |mpf| LibGMP.mpf_div_ui(mpf, self, other) }
    else
      BigFloat.new { |mpf| LibGMP.mpf_div(mpf, self, other.to_big_f) }
    end
  end

  Number.expand_div [Int8, Int16, Int32, Int64, Int128, UInt128], BigFloat
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
