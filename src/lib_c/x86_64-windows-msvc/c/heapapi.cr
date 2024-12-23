require "c/winnt"

lib LibC
  HEAP_ZERO_MEMORY = 0x00000008

  fun GetProcessHeap : HANDLE
  fun HeapAlloc(hHeap : HANDLE, dwFlags : DWORD, dwBytes : SizeT) : Void*
  fun HeapReAlloc(hHeap : HANDLE, dwFlags : DWORD, lpMem : Void*, dwBytes : SizeT) : Void*
  fun HeapFree(hHeap : HANDLE, dwFlags : DWORD, lpMem : Void*) : BOOL
end
