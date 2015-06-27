# The Comparable mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning -1, 0, or +1 depending on whether the receiver is less than,
# equal to, or greater than the other object.
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
    min <= self && self <= max
  end
end
