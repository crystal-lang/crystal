# A Box allows turning any object to a `Void*` and back.
#
# A Box's purpose is passing data to C as a `Void*` and then converting that
# back to the original data type.
#
# For an example usage, see `Proc`'s explanation about sending Procs to C.
class Box(T)
  # Returns the original object
  getter object : T

  # Creates a `Box` with the given object.
  #
  # This method isn't usually used directly. Instead, `Box.box` is used.
  def initialize(@object : T)
  end

  # Creates a Box for an object and returns it as a `Void*`.
  def self.box(object) : Void*
    new(object).as(Void*)
  end

  # Unboxes a `Void*` into an object of type `T`. Note that for this you must
  # specify T: `Box(T).unbox(data)`.
  def self.unbox(pointer : Void*) : T
    pointer.as(self).object
  end
end
