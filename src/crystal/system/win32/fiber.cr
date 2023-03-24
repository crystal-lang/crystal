require "c/memoryapi"
require "c/sysinfoapi"
require "c/winnt"

module Crystal::System::Fiber
  # stack size in bytes needed for last-minute error handling in case of a stack
  # overflow
  RESERVED_STACK_SIZE = LibC::DWORD.new(0x10000)

  # the reserved stack size, plus the size of a single page
  @@total_reserved_size : LibC::DWORD = begin
    LibC.GetNativeSystemInfo(out system_info)
    system_info.dwPageSize + RESERVED_STACK_SIZE
  end

  def self.allocate_stack(stack_size) : Void*
    unless memory_pointer = LibC.VirtualAlloc(nil, stack_size, LibC::MEM_COMMIT | LibC::MEM_RESERVE, LibC::PAGE_READWRITE)
      raise RuntimeError.from_winerror("VirtualAlloc")
    end

    # Detects stack overflows by guarding the top of the stack, similar to
    # `LibC.mprotect`. Windows will fail to allocate a new guard page for these
    # fiber stacks and trigger a stack overflow exception
    if LibC.VirtualProtect(memory_pointer, @@total_reserved_size, LibC::PAGE_READWRITE | LibC::PAGE_GUARD, out _) == 0
      LibC.VirtualFree(memory_pointer, 0, LibC::MEM_RELEASE)
      raise RuntimeError.from_winerror("VirtualProtect")
    end

    memory_pointer
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    if LibC.VirtualFree(stack, 0, LibC::MEM_RELEASE) == 0
      raise RuntimeError.from_winerror("VirtualFree")
    end
  end
end
