@[Deprecated("This module is deprecated as of Crystal 0.28.0. Its behaviour has been fully integrated into `Comparable`.")]
# The `PartialComparable` mixin is used by classes whose objects may be partially ordered.
#
# Including types must provide an `<=>` method, which compares the receiver against
# another object, returning a negative number, `0`, a positive number or `nil` depending on whether
# the receiver is less than, equal to, greater than the other object,
# or no order can be established.
#
# `PartialComparable` uses `<=>` to implement the conventional
# comparison operators (`<`, `<=`, `==`, `>=`, and `>`).
module PartialComparable(T)
  # Compares this object to *other* based on the receiver's `<=>` method,
  # returning `true` if it returns a negative number.
  def <(other : T)
    compare_with(other) do |cmp|
      cmp < 0
    end
  end

  # Compares this object to *other* based on the receiver's `<=>` method,
  # returning `true` if it returns a negative number or `0`.
  def <=(other : T)
    compare_with(other) do |cmp|
      cmp <= 0
    end
  end

  # Compares this object to *other* based on the receiver's `<=>` method,
  # returning `true` if it returns `0`.
  # Also returns `true` if this and *other* are the same object.
  def ==(other : T)
    if self.is_a?(Reference) && (other.is_a?(Reference) || other.is_a?(Nil))
      return true if self.same?(other)
    end

    compare_with(other) do |cmp|
      cmp == 0
    end
  end

  # Compares this object to *other* based on the receiver's `<=>` method,
  # returning `true` if it returns a positive number.
  def >(other : T)
    compare_with(other) do |cmp|
      cmp > 0
    end
  end

  # Compares this object to *other* based on the receiver's `<=>` method,
  # returning `true` if it returns a positive number or `0`.
  def >=(other : T)
    compare_with(other) do |cmp|
      cmp >= 0
    end
  end

  def compare_with(other : T)
    cmp = self <=> other
    if cmp
      yield cmp
    else
      false
    end
  end

  # The comparison operator.
  #
  # Returns a negative number, `0`, a positive number or `nil` depending on whether the object is considered to be less than *other*,
  # equal to *other*, greater than *other* or if no order can be established.
  #
  # Subclasses define this method to provide class-specific ordering.
  #
  # ```
  # # Sort in a descending way
  # [4, 7, 2].sort { |x, y| y <=> x } # => [7, 4, 2]
  # ```
  abstract def <=>(other : T)
end
