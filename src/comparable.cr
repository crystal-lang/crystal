module Comparable(T)
  def <(other : T)
    (self <=> other) < 0
  end

  def <=(other : T)
    (self <=> other) <= 0
  end

  def ==(other : T)
    (self <=> other) == 0
  end

  def >(other : T)
    (self <=> other) > 0
  end

  def >=(other : T)
    (self <=> other) >= 0
  end

  def between?(min, max)
    min < self && self < max
  end
end
