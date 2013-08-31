class Number
  def step(limit, step = 1)
    x = self
    if step > 0 && self < limit
      while x <= limit
        yield x
        x += step
      end
    elsif step < 0 && self > limit
      while x >= limit
        yield x
        x += step
      end
    end
    self
  end

  def abs
    self < 0 ? -self : self
  end

  def <=>(other)
    self > other ? 1 : (self < other ? -1 : 0)
  end
end
