struct Number
  def step(limit = nil, by = 1)
    x = self

    if limit
      if by > 0
        while x <= limit
          yield x
          x += by
        end
      elsif by < 0
        while x >= limit
          yield x
          x += by
        end
      end
    else
      while true
        yield x
        x += by
      end
    end

    self
  end

  def abs
    self < 0 ? -self : self
  end

  def sign
    self < 0 ? -1 : (self == 0 ? 0 : 1)
  end

  def divmod(number)
    {self / number, self % number}
  end

  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end

  def significant(digits, base = 10)
    if digits < 0
      raise ArgumentError.new "digits should be non-negative"
    end

    x = self.to_f

    if x == 0 
        return x
    end

    y = if base == 10
      10 ** ((Math.log10(self.abs) - digits + 1).floor)
    elsif base == 2
      2 ** ((Math.log2(self.abs) - digits + 1).floor)
    else
      base ** (((Math.log2(self.abs)) / (Math.log2(base)) - digits + 1).floor)
    end

    (x / y).round * y
  end

  def round(digits, base = 10)
    x = self.to_f
    y = base ** digits
    (x * y).round / y
  end
end
