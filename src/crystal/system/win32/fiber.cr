require "c/memoryapi"
require "c/winnt"

module Crystal::System::Fiber
  def self.allocate_stack(stack_size) : Void*
    memory_pointer = LibC.VirtualAlloc(nil, stack_size, LibC::MEM_COMMIT | LibC::MEM_RESERVE, LibC::PAGE_READWRITE)

    if memory_pointer.null?
      raise RuntimeError.from_winerror("VirtualAlloc")
    end

    memory_pointer
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    if LibC.VirtualFree(stack, stack_size, LibC::MEM_RELEASE) == 0
      raise RuntimeError.from_winerror("VirtualFree")
    end
  end
end
