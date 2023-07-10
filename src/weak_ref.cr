# Weak Reference class that allows a referenced object to be garbage-collected.
#
# WARNING: The referenced object cannot be a module.
# NOTE: To use `WeakRef`, you must explicitly import it with `require "weak_ref"`
#
# ```
# require "weak_ref"
#
# ref = WeakRef.new("oof".reverse)
# p ref.value # => "foo"
# GC.collect
# p ref.value # => nil
# ```
class WeakRef(T)
  @target : Void*

  def initialize(target : T)
    {% raise "Cannot create a WeakRef of a module" if T.module? %}

    @target = target.as(Void*)
    if GC.is_heap_ptr(@target)
      GC.register_disappearing_link(pointerof(@target))
    end
  end

  # :nodoc:
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
