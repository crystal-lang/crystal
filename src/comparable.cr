# The `Comparable` mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning a negative number, zero, or a positive number depending
# on whether the receiver is less than, equal to, or greater than the other object.
#
# `Comparable` uses `<=>` to implement the conventional comparison operators (`<`, `<=`, `==`, `>=`, and `>`).
module Comparable(T)
  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns a negative number.
  def <(other : T)
    (self <=> other) < 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns a negative number or zero.
  def <=(other : T)
    (self <=> other) <= 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns zero.
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

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns a positive number.
  def >(other : T)
    (self <=> other) > 0
  end

  # Compares this object to *other* based on the receiver’s `<=>` method, returning `true` if it returns a positive number or zero.
  def >=(other : T)
    (self <=> other) >= 0
  end

  # The comparison operator.
  #
  # Returns zero if the two objects are equal,
  # a negative number if this object is considered to be less than *other*,
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
