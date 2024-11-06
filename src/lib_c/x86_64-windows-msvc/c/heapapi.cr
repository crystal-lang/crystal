require "c/winnt"

lib LibC
  fun GetProcessHeap : HANDLE
  fun HeapAlloc(hHeap : HANDLE, dwFlags : DWORD, dwBytes : SizeT) : Void*
  fun HeapReAlloc(hHeap : HANDLE, dwFlags : DWORD, lpMem : Void*, dwBytes : SizeT) : Void*
  fun HeapFree(hHeap : HANDLE, dwFlags : DWORD, lpMem : Void*) : BOOL
end
