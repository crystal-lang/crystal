# :nodoc:
struct Crystal::FiberLocalStorage
  # If crystal code is called from an external thread
  # created from an external library, we may need to
  # create a FLS dynamically using the GC.
  include Crystal::PointerLinkedList::Node

  @[ThreadLocal(unsafe: true)]
  @@fls : Pointer(Void) = Pointer(Void).new(0)

  @@containers : Crystal::PointerLinkedList(self) = Crystal::PointerLinkedList(self).new
  @@list_lock : Mutex = Mutex.new(:unchecked)

  @[AlwaysInline]
  def self.fls : Void*
    ret = @@fls || register_self
    Intrinsics.unreachable unless @@fls
    ret
  end

  @[AlwaysInline]
  def self.fls=(@@fls : Void*)
  end

  # Registers a dynamic FLS section for this fiber using the GC
  @[NoInline]
  def self.register_self : Void*
    Crystal.trace :sched, "fls_create"

    container = GC.malloc(sizeof(self))

    # There's no pointer-based unsafe_construct for struct
    container.as(self*).value = self.new

    @@list_lock.synchronize do
      @@containers.push(container.as(self*))
    end

    Fiber.current.fls = container
    @@fls = container
  end

  # Destroys the dynamic FLS section of this fiber
  # if it was created using the GC
  @[NoInline]
  def self.unregister_self : Nil
    container = @@fls

    return if !container.as(self*).value.previous && !container.as(self*).value.next

    Crystal.trace :sched, "fls_destroy"

    @@list_lock.synchronize do
      @@containers.delete(container.as(self*))
    end

    Fiber.current.fls = Pointer(Void).null
    @@fls = Pointer(Void).null
    GC.free(container)
  end
end

# Defines a fiber-local property.
#
# Note that the code used for generating the default value
# is executed for every new fiber created,
# so it can have a big impact on overall performance.
#
# Example:
# ```
# class Foo
#   private fiber_local cache : Array(Int32)? = nil
# end
# ```
macro fiber_local(var)
  {% unless var.is_a?(TypeDeclaration) %}
    {% var.raise "fiber_local requires a type declaration.\n\
                  Example: fiber_local pcre_context : Void* = Pointer(Void).null" %}
  {% end %}
  {% unless var.value %}
    {% var.raise "fiber_local requires a default value" %}
  {% end %}
  {% if @def %}
    {% var.raise "Cannot define fiber_local variables dynamically" %}
  {% end %}

  struct ::Crystal::FiberLocalStorage
    @%var : {{var.type}} = {{var.value}}
  end

  def self.{{var.var.id}} : {{var.type}}
    ptr = ::Crystal::FiberLocalStorage.fls + offsetof(::Crystal::FiberLocalStorage, @%var)
    ptr.as({{var.type}}*).value
  end

  def self.{{var.var.id}}=(value : {{var.type}})
    ptr = ::Crystal::FiberLocalStorage.fls + offsetof(::Crystal::FiberLocalStorage, @%var)
    ptr.as({{var.type}}*).value = value
  end
end
