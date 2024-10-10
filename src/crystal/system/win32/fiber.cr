require "c/memoryapi"
require "c/sysinfoapi"
require "c/winnt"

module Crystal::System::Fiber
  # stack size in bytes needed for last-minute error handling in case of a stack
  # overflow
  RESERVED_STACK_SIZE = LibC::DWORD.new(0x10000)

  def self.allocate_stack(stack_size, protect) : Void*
    if stack_top = LibC.VirtualAlloc(nil, stack_size, LibC::MEM_RESERVE, LibC::PAGE_READWRITE)
      if protect
        if commit_and_guard(stack_top, stack_size)
          return stack_top
        end
      else
        # for the interpreter, the stack is just ordinary memory so the entire
        # range is committed
        if LibC.VirtualAlloc(stack_top, stack_size, LibC::MEM_COMMIT, LibC::PAGE_READWRITE)
          return stack_top
        end
      end

      # failure
      LibC.VirtualFree(stack_top, 0, LibC::MEM_RELEASE)
    end

    raise RuntimeError.from_winerror("VirtualAlloc")
  end

  def self.reset_stack(stack : Void*, stack_size : Int, protect : Bool) : Nil
    if protect
      if LibC.VirtualFree(stack, 0, LibC::MEM_DECOMMIT) == 0
        raise RuntimeError.from_winerror("VirtualFree")
      end
      unless commit_and_guard(stack, stack_size)
        raise RuntimeError.from_winerror("VirtualAlloc")
      end
    end
  end

  # Commits the bottommost page and sets up the guard pages above it, in the
  # same manner as each thread's main stack. When the stack hits a guard page
  # for the first time, a page fault is generated, the page's guard status is
  # reset, and Windows checks if a reserved page is available above. On success,
  # a new guard page is committed, and on failure, a stack overflow exception is
  # triggered after the `RESERVED_STACK_SIZE` portion is made available.
  private def self.commit_and_guard(stack_top, stack_size)
    stack_bottom = stack_top + stack_size

    LibC.GetNativeSystemInfo(out system_info)
    stack_commit_size = system_info.dwPageSize
    stack_commit_top = stack_bottom - stack_commit_size
    unless LibC.VirtualAlloc(stack_commit_top, stack_commit_size, LibC::MEM_COMMIT, LibC::PAGE_READWRITE)
      return false
    end

    # the reserved stack size, plus a final guard page for when the stack
    # overflow handler itself overflows the stack
    stack_guard_size = system_info.dwPageSize + RESERVED_STACK_SIZE
    stack_guard_top = stack_commit_top - stack_guard_size
    unless LibC.VirtualAlloc(stack_guard_top, stack_guard_size, LibC::MEM_COMMIT, LibC::PAGE_READWRITE | LibC::PAGE_GUARD)
      return false
    end

    true
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    if LibC.VirtualFree(stack, 0, LibC::MEM_RELEASE) == 0
      raise RuntimeError.from_winerror("VirtualFree")
    end
  end
end
