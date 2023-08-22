lib LibC
  MEM_COMMIT     = 0x00001000
  MEM_RESERVE    = 0x00002000
  MEM_RESET      = 0x00080000
  MEM_RESET_UNDO = 0x01000000

  fun VirtualAlloc(lpAddress : Void*, dwSize : SizeT, flAllocationType : DWORD, flProtect : DWORD) : Void*

  MEM_DECOMMIT = 0x4000
  MEM_RELEASE  = 0x8000

  fun VirtualFree(lpAddress : Void*, dwSize : SizeT, dwFreeType : DWORD) : BOOL
  fun VirtualProtect(lpAddress : Void*, dwSize : SizeT, flNewProtect : DWORD, lpfOldProtect : DWORD*) : BOOL
  fun VirtualQuery(lpAddress : Void*, lpBuffer : MEMORY_BASIC_INFORMATION*, dwLength : SizeT)
end
