require "c/memoryapi"

module Crystal::System
  struct Crystal::System::MemoryMap
    @map_handle : LibC::HANDLE

    def initialize(@map_handle, @pointer, @size, @read_only)
    end

    def unmap : Nil | WinError
      if LibC.UnmapViewOfFile(@pointer) == 0
        error = WinError.new
      end

      if LibC.CloseHandle(@map_handle) == 0
        error ||= WinError.new
      end

      error
    end
  end

  def self.memory_map(handle : FileDescriptor::Handle, offset : Int, size : Int, read_only = true) : MemoryMap | WinError
    size_t = LibC::SizeT.new(size)

    map_handle = LibC.CreateFileMappingA(
      handle,
      nil,
      read_only ? LibC::PAGE_READONLY : LibC::PAGE_READWRITE,
      LibC::DWORD.new!(size >> 32),
      LibC::DWORD.new!(size),
      nil
    )
    if map_handle == LibC::INVALID_HANDLE_VALUE
      return WinError.value
    end

    map_access = LibC::FILE_MAP_READ
    map_access |= LibC::FILE_MAP_WRITE unless read_only

    pointer = LibC.MapViewOfFile(
      map_handle,
      map_access,
      LibC::DWORD.new!(offset >> 32),
      LibC::DWORD.new!(offset),
      size_t
    )
    if pointer.null?
      LibC.CloseHandle(map_handle)
      return WinError.value
    end

    MemoryMap.new(pointer.as(UInt8*), size_t, read_only)
  end
end
