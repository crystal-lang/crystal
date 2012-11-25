class Numeric
  def step(limit, step)
    x = self
    while x <= limit
      yield x
      x += step
    end
  end
end