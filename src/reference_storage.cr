# `ReferenceStorage(T)` provides the minimum storage for the instance data of
# an object of type `T`. The compiler guarantees that
# `sizeof(ReferenceStorage(T)) == instance_sizeof(T)` and
# `alignof(ReferenceStorage(T)) == instance_alignof(T)` always hold, which means
# `Pointer(ReferenceStorage(T))` and `T` are binary-compatible.
#
# `T` must be a non-union reference type.
#
# WARNING: `ReferenceStorage` is only necessary for manual memory management,
# such as creating instances of `T` with a non-default allocator. Therefore,
# this type is unsafe and no public constructors are defined.
#
# WARNING: `ReferenceStorage` is unsuitable when instances of `T` require more
# than `instance_sizeof(T)` bytes, such as `String` and `Log::Metadata`.
@[Experimental("This type's API is still under development. Join the discussion about custom reference allocation at [#13481](https://github.com/crystal-lang/crystal/issues/13481).")]
@[Primitive(:ReferenceStorageType)]
struct ReferenceStorage(T) < Value
  private def initialize
  end

  # Returns whether `self` and *other* are bytewise equal.
  #
  # NOTE: This does not call `T#==`, so it works even if `self` or *other* does
  # not represent a valid instance of `T`. If validity is guaranteed, call
  # `to_reference == other.to_reference` instead to use `T#==`.
  def ==(other : ReferenceStorage(T)) : Bool
    to_bytes == other.to_bytes
  end

  def ==(other) : Bool
    false
  end

  def hash(hasher)
    to_bytes.hash(hasher)
  end

  def to_s(io : IO) : Nil
    io << "ReferenceStorage(#<" << T << ":0x"
    pointerof(@type_id).address.to_s(io, 16)
    io << ">)"
  end

  # Returns a `T` whose instance data refers to `self`.
  #
  # WARNING: The caller is responsible for ensuring that the instance data is
  # correctly initialized and outlives the returned `T`.
  def to_reference : T
    pointerof(@type_id).as(T)
  end

  protected def to_bytes
    Slice.new(pointerof(@type_id).as(UInt8*), instance_sizeof(T))
  end
end
