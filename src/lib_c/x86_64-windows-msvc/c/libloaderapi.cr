require "c/winnt"

@[Link("Kernel32")]
lib LibC
  alias FARPROC = Void*

  fun LoadLibraryExA(lpLibFileName : LPSTR, hFile : HANDLE, dwFlags : DWORD) : HMODULE
  fun LoadLibraryExW(lpLibFileName : LPWSTR, hFile : HANDLE, dwFlags : DWORD) : HMODULE
  fun FreeLibrary(hLibModule : HMODULE) : BOOL

  fun GetModuleHandleExW(dwFlags : DWORD, lpModuleName : LPWSTR, phModule : HMODULE*) : BOOL

  fun GetProcAddress(hModule : HMODULE, lpProcName : LPSTR) : FARPROC

  fun GetModuleFileNameW(hModule : HMODULE, lpFilename : LPWSTR, nSize : DWORD) : DWORD
end
