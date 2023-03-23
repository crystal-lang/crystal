require "c/memoryapi"
require "c/sysinfoapi"
require "c/winnt"

module Crystal::System::Fiber
  RESERVED_STACK_SIZE = LibC::DWORD.new(0x10000)

  private class_getter page_size : LibC::DWORD do
    LibC.GetNativeSystemInfo(out system_info)
    system_info.dwPageSize
  end

  def self.allocate_stack(stack_size) : Void*
    # This reserves and commits a stack slightly larger than the given size,
    # partitioned in ascending order of address values:
    #
    # * reserved (`RESERVED_STACK_SIZE`), made available by `LibC._resetstkoflw`
    #   for last-minute error handling in case of stack overflow
    # * guard (a single page), detects stack overflows
    # * the actual usable stack (*stack_size*), grows upwards
    #
    # Only the usable region is returned, and this stack is treated like the
    # ones on main fibers; a non-main `Fiber` never needs to know about the
    # existence of the reserved area. Stack overflow detection works because
    # Windows will fail to allocate a new guard page for these fiber stacks.

    page_size = self.page_size
    total_reserved = page_size + RESERVED_STACK_SIZE

    unless memory_pointer = LibC.VirtualAlloc(nil, stack_size + total_reserved, LibC::MEM_COMMIT | LibC::MEM_RESERVE, LibC::PAGE_READWRITE)
      raise RuntimeError.from_winerror("VirtualAlloc")
    end

    if LibC.VirtualProtect(memory_pointer + RESERVED_STACK_SIZE, page_size, LibC::PAGE_READWRITE | LibC::PAGE_GUARD, out _) == 0
      LibC.VirtualFree(memory_pointer, 0, LibC::MEM_RELEASE)
      raise RuntimeError.from_winerror("VirtualProtect")
    end

    memory_pointer + total_reserved
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    total_reserved = page_size + RESERVED_STACK_SIZE
    if LibC.VirtualFree(stack - total_reserved, 0, LibC::MEM_RELEASE) == 0
      raise RuntimeError.from_winerror("VirtualFree")
    end
  end
end
