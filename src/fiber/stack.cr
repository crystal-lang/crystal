class Fiber
  # :nodoc:
  struct Stack
    getter pointer : Void*
    getter bottom : Void*
    getter size : Int32
    getter? reusable : Bool

    def initialize(@pointer : Void*, @bottom : Void*, *, @reusable = false)
      # NOTE: sometimes gc/boehm reports weird stacks on linux (over 2GB)
      @size = (@bottom - @pointer).to_i32!
    end

    def initialize(@pointer : Void*, @size : Int32, *, @reusable = false)
      @bottom = @pointer + @size
    end

    def first_addressable_pointer : Void**
      ptr = @bottom                             # stacks grow down
      ptr -= sizeof(Void*)                      # point to first addressable pointer
      Pointer(Void*).new(ptr.address & ~15_u64) # align to 16 bytes
    end
  end
end
