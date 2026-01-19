class Fiber
  # :nodoc:
  struct Stack
    getter pointer : Void*
    getter bottom : Void*
    getter size : Int32
    getter? reusable : Bool

    # Constructor for thread stacks (main fibers).
    def initialize(@pointer : Void*, @bottom : Void*, *, @reusable = false)
      # FIXME: sometimes gc/boehm reports weird stack limits on linux (over
      # 2GB) at least, so we always cast to i32 without overflow checks.
      @size = (@bottom - @pointer).to_i32!
    end

    # Constructor for fiber stacks.
    def initialize(@pointer : Void*, @size : Int32, *, @reusable = false)
      @bottom = @pointer + @size
    end

    def first_addressable_pointer : Void**
      ptr = @bottom        # stacks grow down
      ptr -= sizeof(Void*) # point to first addressable pointer
      ptr.align_down(16)   # align to 16 bytes
    end
  end
end
