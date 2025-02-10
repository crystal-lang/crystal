class Fiber
  # :nodoc:
  struct Stack
    getter pointer : Void*
    getter bytesize : Int32
    getter? reusable : Bool

    def initialize(@pointer, bottom : Void*, *, @reusable = false)
      @bytesize = (bottom - @pointer).to_i32
    end

    def initialize(@pointer, @bytesize, *, @reusable = false)
    end

    def bottom : Void*
      @pointer + @bytesize
    end

    def first_addressable_pointer : Void**
      ptr = bottom                              # stacks grow down
      ptr -= sizeof(Void*)                      # point to first addressable pointer
      Pointer(Void*).new(ptr.address & ~15_u64) # align to 16 bytes
    end
  end
end
