require "c/sys/mman"

module Crystal::System::Fiber
  def self.allocate_stack(stack_size, protect) : Void*
    flags = LibC::MAP_PRIVATE | LibC::MAP_ANON
    {% if flag?(:openbsd) %}
      flags |= LibC::MAP_STACK
    {% end %}

    pointer = LibC.mmap(nil, stack_size, LibC::PROT_READ | LibC::PROT_WRITE, flags, -1, 0)
    raise RuntimeError.from_errno("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED

    {% if flag?(:linux) %}
      LibC.madvise(pointer, stack_size, LibC::MADV_NOHUGEPAGE)
    {% end %}

    if protect
      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
    end

    pointer
  end

  def self.reset_stack(stack : Void*, stack_size : Int, protect : Bool) : Nil
  end

  def self.free_stack(stack : Void*, stack_size) : Nil
    LibC.munmap(stack, stack_size)
  end
end
