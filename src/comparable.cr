# The `Comparable` mixin is used by classes whose objects may be ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning:
# - a value less than zero if `self` is less than the other object
# - a value greater than zero if `self` is greater than the other object
# - zero if `self` is equal to the other object
# - `nil` if `self` and the other object are not comparable
#
# `Comparable` uses `<=>` to implement the conventional comparison operators
# (`<`, `<=`, `==`, `>=`, and `>`).
#
# Note that returning `nil` is only useful when defining a partial comparable
# relationship. One such example is float values: they are generally comparable,
# except for `NaN`. If none of the values of a type are comparable between each
# other, `Comparable` shouldn't be included.
#
# NOTE: when `nil` is returned from `<=>`, `Array#sort` and related sorting
# methods will perform slightly slower.
module Comparable(T)
  # Compares this object to *other* based on the receiver’s `<=>` method,
  # returning `true` if it returns a value less than zero.
  def <(other : T)
    cmp = self <=> other
    cmp ? cmp < 0 : false
  end

  # Compares this object to *other* based on the receiver’s `<=>` method,
  # returning `true` if it returns a value equal or less then zero.
  def <=(other : T)
    cmp = self <=> other
    cmp ? cmp <= 0 : false
  end

  # Compares this object to *other* based on the receiver’s `<=>` method,
  # returning `true` if it returns `0`.
  #
  # Also returns `true` if this and *other* are the same object.
  def ==(other : T)
    if self.is_a?(Reference)
      # Need to do two different comparisons because the compiler doesn't yet
      # restrict something like `other.is_a?(Reference) || other.is_a?(Nil)`.
      # See #2461
      return true if other.is_a?(Reference) && self.same?(other)
      return true if other.is_a?(Nil) && self.same?(other)
    end

    cmp = self <=> other
    cmp ? cmp == 0 : false
  end

  # Compares this object to *other* based on the receiver’s `<=>` method,
  # returning `true` if it returns a value greater then zero.
  def >(other : T)
    cmp = self <=> other
    cmp ? cmp > 0 : false
  end

  # Compares this object to *other* based on the receiver’s `<=>` method,
  # returning `true` if it returns a value equal or greater than zero.
  def >=(other : T)
    cmp = self <=> other
    cmp ? cmp >= 0 : false
  end

  # The comparison operator. Returns `0` if the two objects are equal,
  # a negative number if this object is considered less than *other*,
  # a positive number if this object is considered greter than *other*,
  # or `nil` if the two objects are not comparable.
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
