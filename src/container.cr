# The `Container` module models types which hold a finite number of elements of
# type `T`. This number can be queried, and the elements can be iterated over
# multiple times.
#
# The following criteria must hold for any container `x`:
#
# * Calling `x.each { }` or `x.size` must not modify the number and order of
#   the elements in `x`;
# * `x.size` must be equal to the number of values yielded in a call to
#   `x.each { }`.
#
# It is unspecified whether modifying a container within an active iteration
# would affect the order of the remaining elements yet to be yielded.
#
# Typical including types in the standard library are `Indexable`, `Set`, and
# `Hash`, which match the intuitive notion of a "container".
#
# Examples of types that include `Enumerable` but _not_ `Container` are
# `Iterator` and `Char::Reader`, because calling `#each` on these objects
# consumes their elements.
module Container(T)
  include Enumerable(T)

  # Returns the number of elements in this container.
  abstract def size

  def self.cartesian_product(containers : Container(Container))
    capacity = containers.product(&.size)
    result = Array(Array(typeof(Enumerable.element_type Enumerable.element_type containers))).new(capacity)
    each_cartesian(containers) do |product|
      result << product
    end
    result
  end

  def self.each_cartesian(containers : Container(Container), reuse = false, &block)
    lens = containers.map &.size
    return if lens.any? &.zero?

    containers = containers.map { |c| dup_as_array(c) }
    n = containers.size
    pool = Array.new(n) { |i| containers.unsafe_fetch(i).unsafe_fetch(0) }
    indices = Array.new(n, 0)
    reuse = Indexable(typeof(pool.first)).check_reuse(reuse, n)

    while true
      yield pool_slice(pool, n, reuse)

      i = n

      while true
        i -= 1
        return if i < 0
        indices[i] += 1
        if move_to_next = (indices[i] >= lens[i])
          indices[i] = 0
        end
        pool[i] = containers[i].unsafe_fetch(indices[i])
        break unless move_to_next
      end
    end
  end
end

private def pool_slice(pool, size, reuse)
  if reuse
    reuse.clear
    size.times { |i| reuse << pool[i] }
    reuse
  else
    pool[0, size]
  end
end

private def dup_as_array(a)
  a.is_a?(Array) ? a.dup : a.to_a
end
