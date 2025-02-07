class Fiber
  # :nodoc:
  struct Stack
    getter pointer : Void*
    getter bottom : Void*
    getter? reusable : Bool

    def self.new : self
      {% if flag?(:interpreted) %}
        new Pointer(Void).null, Pointer(Void).null
      {% else %}
        stack, stack_bottom = Crystal::Scheduler.stack_pool.checkout
        new(stack, stack_bottom, reusable: true)
      {% end %}
    end

    def initialize(@pointer, @bottom, *, @reusable = false)
    end

    def first_addressable_pointer : Void**
      ptr = @bottom                             # stacks grow down
      ptr -= sizeof(Void*)                      # point to first addressable pointer
      Pointer(Void*).new(ptr.address & ~15_u64) # align to 16 bytes
    end

    def release : Nil
      Crystal::Scheduler.stack_pool.release(@pointer) if @reusable
    end
  end
end
