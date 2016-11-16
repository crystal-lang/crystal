# Compute the Bernoulli numbers, the worlds first computer program
# Taken from the 'Ada 99' project, https://marquisdegeek.com/code_ada99

class Fraction
  def initialize(n : Int32, d : Int32)
    @numerator = n
    @denominator = d
  end

  def numerator
    @numerator
  end

  def denominator
    @denominator
  end

  def subtract(rhs_fraction)
    rhs_numerator = rhs_fraction.numerator * @denominator
    rhs_denominator = rhs_fraction.denominator * @denominator
    @numerator *= rhs_fraction.denominator
    @denominator *= rhs_fraction.denominator
    @numerator -= rhs_numerator
    self.reduce
  end

  def multiply(value)
    @numerator *= value
  end

  def reduce
    gcd = gcd(@numerator, @denominator)
    @numerator /= gcd
    @denominator /= gcd
  end

  def to_s
    @numerator == 0 ? 0 : @numerator.to_s + '/' + @denominator.to_s
  end
end

def gcd(a, b)
  # we need b>0 because b on its own isn't considered true
  b > 0 ? gcd(b, a % b) : a
end

def calculateBernoulli(bern)
  row = [] of Fraction
  0.step(bern) do |m|
    row << Fraction.new(1, m + 1)
    m.step(1, -1) do |j|
      row[j - 1].subtract(row[j])
      row[j - 1].multiply(j)
      row[j - 1].reduce
    end
  end

  row[0]
end

# Int32's are only big enough to calculate to 17 Bernoulli numbers
# Any greater and we get 1/0 due to overflow and division by zero errors
1.step(17) do |bern|
  puts calculateBernoulli(bern).to_s
end
