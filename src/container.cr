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
end
