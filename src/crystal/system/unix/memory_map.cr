require "c/sys/mman"

module Crystal::System
  struct MemoryMap
    def initialize(@pointer, @size, @read_only)
    end

    def unmap : Nil | Errno
      unless LibC.munmap(@pointer, @size) == 0
        Errno.value
      end
    end
  end

  def self.memory_map(handle : FileDescriptor::Handle, offset : Int, size : Int, read_only = true) : MemoryMap | Errno
    size_t = LibC::SizeT.new(size)
    protect = LibC::PROT_READ
    protect |= LibC::PROT_WRITE unless read_only

    pointer = LibC.mmap(nil, size_t, protect, LibC::MAP_PRIVATE, handle, offset)
    return Errno.value if pointer == LibC::MAP_FAILED

    MemoryMap.new(pointer.as(UInt8*), size_t, read_only)
  end
end
