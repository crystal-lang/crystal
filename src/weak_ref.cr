# Weak Reference class that allows a referenced object to be garbage-collected.
#
# ```
# ref = WeakRef.new("oof".reverse)
# p ref.target # => "foo"
# GC.collect
# p ref.target # => nil
# ```
#
# NOTE: Creating a weak reference of a literal (e.g. "foo") will crash your
# application. This is the reason for using `"oof".reverse` in the above
# example.
class WeakRef(T)
  @target : Void*

  def initialize(target : T)
    @target = target.as(Void*)
    if GC.is_heap_ptr(@target)
      GC.register_disappearing_link(pointerof(@target))
    end
  end

  def self.allocate
    ptr = GC.malloc_atomic(instance_sizeof(self)).as(self)
    set_crystal_type_id(ptr)
    ptr
  end

  # Returns the referenced object or `Nil` if it has been garbage-collected.
  def value
    @target.as(T?)
  end
end
