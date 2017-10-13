require "big"

module Math
  def sqrt(value : BigRational)
    sqrt(value.to_big_f)
  end

  def sqrt(value : BigInt)
    sqrt(value.to_big_f)
  end

  def sqrt(value : BigFloat)
    BigFloat.new { |mpf| LibGMP.mpf_sqrt(mpf, value) }
  end
end
