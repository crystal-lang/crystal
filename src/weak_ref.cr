# Weak Reference class that allows a referenced object to be garbage-collected.
#
# ```
# require "weak_ref"
#
# ref = WeakRef.new("oof".reverse)
# p ref # => #<WeakRef(String):0x7f83406eafa0 @target=Pointer(Void)@0x7f83406eafc0>
# GC.collect
# p ref       # => #<WeakRef(String):0x7f83406eafa0 @target=Pointer(Void).null>
# p ref.value # => nil
# ```
#
# Note that the collection of objects is not deterministic, and depends on many subtle aspects. For instance,
# if the example above is modified to print `ref.value` in the first print, then the collector will not collect it.
class WeakRef(T)
  @target : Void*

  def initialize(target : T)
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
