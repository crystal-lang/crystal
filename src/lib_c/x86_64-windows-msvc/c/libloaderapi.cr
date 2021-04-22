require "c/winnt"

lib LibC
  fun GetModuleFileNameW(hModule : HMODULE, lpFilename : LPWSTR, nSize : DWORD) : DWORD
end
