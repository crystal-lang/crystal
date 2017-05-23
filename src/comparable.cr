# The `Comparable` mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning `-1`, `0`, or `+1` depending on whether the receiver is less than,
# equal to, or greater than the other object.
#
# `Comparable` uses `<=>` to implement the conventional comparison operators (`<`, `<=`, `==`, `>=`, and `>`).
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
  # Also returns `true` if this and *other* are the same object.
  def ==(other : T)
    if self.is_a?(Reference)
      # Need to do two different comparisons because the compiler doesn't yet
      # restrict something like `other.is_a?(Reference) || other.is_a?(Nil)`.
      # See #2461
      return true if other.is_a?(Reference) && self.same?(other)
      return true if other.is_a?(Nil) && self.same?(other)
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

  # Comparison operator. Returns `0` if the two objects are equal,
  # a negative number if this object is considered less than *other*,
  # or a positive number otherwise.
  #
  # Subclasses define this method to provide class-specific ordering.
  #
  # ```
  # # Sort in a descending way
  # [4, 7, 2].sort { |x, y| y <=> x } # => [7, 4, 2]
  # ```
  abstract def <=>(other : T)
end
