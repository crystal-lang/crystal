# :nodoc:
class Thread
  # :nodoc:
  struct Stack
    property top : Pointer(Void)  # Lowest address of a writeable byte
    property stack_size : UInt64  # Size in bytes
    property guard_size : UInt64? # Nil if guard_size is unknown

    def initialize(@top, @stack_size, @guard_size = nil)
    end

    def bottom
      top + stack_size
    end
  end
end
