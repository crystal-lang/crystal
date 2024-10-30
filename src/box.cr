# A Box allows turning any object to a `Void*` and back.
#
# A Box's purpose is passing data to C as a `Void*` and then converting that
# back to the original data type.
#
# For an example usage, see `Proc`'s explanation about sending Procs to C.
class Box(T)
  # :nodoc:
  #
  # Returns the original object
  getter object : T

  # :nodoc:
  #
  # Creates a `Box` with the given object.
  #
  # This method isn't usually used directly. Instead, `Box.box` is used.
  def initialize(@object : T)
  end

  # Turns *object* into a `Void*`.
  #
  # If `T` is not a reference type, nor a union between reference types and
  # `Nil`, this method effectively copies *object* to the dynamic heap.
  #
  # NOTE: The returned pointer might not be a null pointer even when *object* is
  # `nil`.
  def self.box(object : T) : Void*
    {% if T.union_types.all? { |t| t == Nil || t < Reference } %}
      object.as(Void*)
    {% else %}
      # NOTE: if `T` is explicitly specified and `typeof(object) < T` (e.g.
      # `Box(Int32?).box(1)`, then `.new` will perform the appropriate upcast
      new(object).as(Void*)
    {% end %}
  end

  # Unboxes a `Void*` into an object of type `T`. Note that for this you must
  # specify T: `Box(T).unbox(data)`.
  #
  # WARNING: It is undefined behavior to box an object in one type and unbox it
  # via a different type; in particular, when boxing a `T` and unboxing it as a
  # `T?`, or vice-versa.
  def self.unbox(pointer : Void*) : T
    {% if T.union_types.all? { |t| t == Nil || t < Reference } %}
      pointer.as(T)
    {% else %}
      pointer.as(self).object
    {% end %}
  end
end
