lib LibC
  MEM_COMMIT     = 0x00001000
  MEM_RESERVE    = 0x00002000
  MEM_RESET      = 0x00080000
  MEM_RESET_UNDO = 0x01000000

  fun VirtualAlloc(lpAddress : Void*, dwSize : SizeT, flAllocationType : DWORD, flProtect : DWORD) : Void*

  MEM_DECOMMIT = 0x4000
  MEM_RELEASE  = 0x8000

  fun VirtualFree(lpAddress : Void*, dwSize : SizeT, dwFreeType : DWORD) : BOOL

  struct MEMORY_BASIC_INFORMATION
    baseAddress : Void*
    allocationBase : Void*
    allocationProtect : DWORD
    partitionId : WORD
    regionSize : SizeT
    state : DWORD
    protect : DWORD
    type : DWORD
  end

  fun VirtualQuery(lpAddress : Void*, lpBuffer : MEMORY_BASIC_INFORMATION*, dwLength : SizeT)
end
