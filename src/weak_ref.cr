# Weak Reference class that allows a referenced object to be garbage-collected.
#
class WeakRef(T)
  @target : Void*

  def initialize(target : T)
    @target = target.as(Void*)
    GC.register_disappearing_link(pointerof(@target))
  end

  def self.allocate
    ptr = GC.malloc_atomic(sizeof(self)).as(self)
    # TODO: uncomment after 0.20.1
    # set_crystal_type_id(ptr)
    ptr
  end

  # Returns the referenced object or `Nil` if it has been garbage-collected.
  def target
    @target.as(T?)
  end
end
