# The `Comparable` mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning a negative number, `0`, or a positive number depending
# on whether the receiver is less than, equal to, or greater than the other object.
#
# `Comparable` uses `<=>` to implement the conventional comparison operators (`<`, `<=`, `==`, `>=`, and `>`).
module Comparable(T)
  # Compares this object to *other* based on the receiver's `<=>` method, returning `true` if it returns a negative number.
  def <(other : T)
    (self <=> other) < 0
  end

  # Compares this object to *other* based on the receiver's `<=>` method, returning `true` if it returns a negative number or `0`.
  def <=(other : T)
    (self <=> other) <= 0
  end

  # Compares this object to *other* based on the receiver's `<=>` method, returning `true` if it returns `0`.
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

  # Compares this object to *other* based on the receiver's `<=>` method, returning `true` if it returns a positive number.
  def >(other : T)
    (self <=> other) > 0
  end

  # Compares this object to *other* based on the receiver's `<=>` method, returning `true` if it returns a positive number or `0`.
  def >=(other : T)
    (self <=> other) >= 0
  end

  # The comparison operator.
  #
  # Returns `-1`, `0` or `1` depending on whether `self` is less than *other*, equals *other*
  # or is greater than *other*.
  #
  # Subclasses define this method to provide class-specific ordering.
  #
  # The comparison operator is usually used to sort values:
  #
  # ```
  # # Sort in a descending way:
  # [3, 1, 2].sort { |x, y| y <=> x } # => [3, 2, 1]
  #
  # # Sort in an ascending way:
  # [3, 1, 2].sort { |x, y| x <=> y } # => [1, 2, 3]
  # ```
  abstract def <=>(other : T)
end
