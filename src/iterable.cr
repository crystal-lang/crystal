# The Iterable mixin provides convenince methods to collection classes
# that provide an `each` method that returns an `Iterator` over the collection.
module Iterable
  # Must return an `Iterator` over the elements in this collection.
  abstract def each

  # Same as `each.cycle`.
  def cycle
    each.cycle
  end

  # Same as `each.cycle(n)`.
  def cycle(n)
    each.cycle(n)
  end

  # Same as `each.slice(count)`.
  def each_slice(count : Int)
    each.slice(count)
  end

  # Same as `each.cons(count)`.
  def each_cons(count : Int)
    each.cons(count)
  end

  # Same as `each.with_index(offset)`.
  def each_with_index(offset = 0)
    each.with_index(offset)
  end

  # Same as `each.with_object(obj)`.
  def each_with_object(obj)
    each.with_object(obj)
  end
end
