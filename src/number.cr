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
end
