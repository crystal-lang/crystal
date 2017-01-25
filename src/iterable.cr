# The `Iterable` mixin provides convenience methods to collection classes
# that provide an `each` method that returns an `Iterator` over the collection.
module Iterable(T)
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

  # Returns an Iterator that enumerates over the items, chunking them together
  # based on the return value of the block.
  #
  # ```
  # (0..7).chunk(&./(3)).to_a # => [{0, [0, 1, 2]}, {1, [3, 4, 5]}, {2, [6, 7]}]
  # ```
  #
  # See also: `Iterator#chunks`.
  def chunk(reuse = false, &block : T -> U) forall U
    each.chunk reuse, &block
  end

  # Same as `each.slice(count, reuse)`.
  def each_slice(count : Int, reuse = false)
    each.slice(count, reuse)
  end

  # Same as `each.cons(count)`.
  def each_cons(count : Int, reuse = false)
    each.cons(count, reuse)
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
