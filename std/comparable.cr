module Comparable
  def <(other : self)
    (self <=> other) < 0
  end

  def <=(other : self)
    (self <=> other) <= 0
  end

  def ==(other : self)
    (self <=> other) == 0
  end

  def >(other : self)
    (self <=> other) > 0
  end

  def >=(other : self)
    (self <=> other) >= 0
  end

  def between?(min, max)
    min < self && self < max
  end
end