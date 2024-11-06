require "c/winnt"

@[Link("Kernel32")]
lib LibC
  alias FARPROC = Void*

  LOAD_WITH_ALTERED_SEARCH_PATH = 0x00000008

  fun LoadLibraryExW(lpLibFileName : LPWSTR, hFile : HANDLE, dwFlags : DWORD) : HMODULE
  fun FreeLibrary(hLibModule : HMODULE) : BOOL

  GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = 0x00000002
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       = 0x00000004

  fun GetModuleHandleExW(dwFlags : DWORD, lpModuleName : LPWSTR, phModule : HMODULE*) : BOOL

  fun GetProcAddress(hModule : HMODULE, lpProcName : LPSTR) : FARPROC

  fun GetModuleFileNameW(hModule : HMODULE, lpFilename : LPWSTR, nSize : DWORD) : DWORD
end
