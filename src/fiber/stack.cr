class Fiber
  # :nodoc:
  struct Stack
    getter pointer : Void*
    getter bottom : Void*
    getter? reusable : Bool

    def initialize(@pointer : Pointer(Void), @bottom : Pointer(Void), *, @reusable : Bool = false)
    end

    def first_addressable_pointer : Void**
      ptr = @bottom                             # stacks grow down
      ptr -= sizeof(Void*)                      # point to first addressable pointer
      Pointer(Void*).new(ptr.address & ~15_u64) # align to 16 bytes
    end
  end
end
