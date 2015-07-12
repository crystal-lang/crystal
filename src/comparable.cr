# The Comparable mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning -1, 0, or +1 depending on whether the receiver is less than,
# equal to, or greater than the other object.
#
# Comparable uses `<=>` to implement the conventional comparison operators (`<`, `<=`, `==`, `>=`, and `>`)
# and the method `between?`.
module Comparable(T)
  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns `-1`.
  def <(other : T)
    (self <=> other) < 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns `-1` or `0`.
  def <=(other : T)
    (self <=> other) <= 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns `0`.
  # Also returns `true` if this and `other` are the same object.
  def ==(other : T)
    if self.is_a?(Reference) && (other.is_a?(Reference) || other.is_a?(Nil))
      return true if self.same?(other)
    end

    (self <=> other) == 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns `1`.
  def >(other : T)
    (self <=> other) > 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns `1` or `0`.
  def >=(other : T)
    (self <=> other) >= 0
  end

  # Returns `false` if `self <=> min` is less than zero or if `self <=> max` is greater than zero, `true` otherwise.
  def between?(min, max)
    min <= self && self <= max
  end
end
