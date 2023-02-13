# The `Iterable` mixin provides convenience methods to collection classes
# that provide an `each` method that returns an `Iterator` over the collection.
module Iterable(T)
  # Must return an `Iterator` over the elements in this collection.
  abstract def each

  # Same as `each.cycle`.
  #
  # See also: `Iterator#cycle`.
  def cycle
    each.cycle
  end

  # Same as `each.cycle(n)`.
  #
  # See also: `Iterator#cycle(n)`.
  def cycle(n)
    each.cycle(n)
  end

  # Returns an Iterator that enumerates over the items, chunking them together
  # based on the return value of the block.
  #
  # ```
  # (0..7).chunk(&.//(3)).to_a # => [{0, [0, 1, 2]}, {1, [3, 4, 5]}, {2, [6, 7]}]
  # ```
  #
  # See also: `Iterator#chunk`.
  def chunk(reuse = false, &block : T -> U) forall U
    each.chunk reuse, &block
  end

  # Same as `each.slice(count, reuse)`.
  #
  # See also: `Iterator#slice(count, reuse)`.
  def each_slice(count : Int, reuse = false)
    each.slice(count, reuse)
  end

  # Same as `each.cons(count, reuse)`.
  #
  # See also: `Iterator#cons(count, reuse)`.
  def each_cons(count : Int, reuse = false)
    each.cons(count, reuse)
  end

  # Same as `each.cons_pair`.
  #
  # See also: `Iterator#cons_pair`.
  def each_cons_pair
    each.cons_pair
  end

  # Same as `each.with_index(offset)`.
  #
  # See also: `Iterator#with_index(offset)`.
  def each_with_index(offset = 0)
    each.with_index(offset)
  end

  # Same as `each.with_object(obj)`.
  #
  # See also: `Iterator#with_object(obj)`.
  def each_with_object(obj)
    each.with_object(obj)
  end

  # Same as `each.slice_after(reuse, &block)`.
  #
  # See also: `Iterator#slice_after(reuse, &block)`.
  def slice_after(reuse : Bool | Array(T) = false, &block : T -> B) forall B
    each.slice_after(reuse, &block)
  end

  # Same as `each.slice_after(pattern, reuse)`.
  #
  # See also: `Iterator#slice_after(pattern, reuse)`.
  def slice_after(pattern, reuse : Bool | Array(T) = false)
    each.slice_after(pattern, reuse)
  end

  # Same as `each.slice_before(reuse, &block)`.
  #
  # See also: `Iterator#slice_before(reuse, &block)`.
  def slice_before(reuse : Bool | Array(T) = false, &block : T -> B) forall B
    each.slice_before(reuse, &block)
  end

  # Same as `each.slice_before(pattern, reuse)`.
  #
  # See also: `Iterator#slice_before(pattern, reuse)`.
  def slice_before(pattern, reuse : Bool | Array(T) = false)
    each.slice_before(pattern, reuse)
  end

  # Same as `each.slice_when(reuse, &block)`.
  #
  # See also: `Iterator#slice_when`.
  def slice_when(reuse : Bool | Array(T) = false, &block : T, T -> B) forall B
    each.slice_when(reuse, &block)
  end

  # Same as `each.chunk_while(reuse, &block)`.
  #
  # See also: `Iterator#chunk_while`.
  def chunk_while(reuse : Bool | Array(T) = false, &block : T, T -> B) forall B
    each.chunk_while(reuse, &block)
  end
end
