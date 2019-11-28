require "c/basetsd"

lib LibC
  alias WORD = UInt16
  alias WCHAR = UInt16

  alias LPSTR = CHAR*
  alias PWSTR = WCHAR*
  alias LPWSTR = WCHAR*
  alias LPWCH = WCHAR*
  alias LPCWSTR = LPWSTR
  alias PCWSTR = WCHAR*
  alias PVOID = Void*
  alias LPVOID = PVOID
  alias LPBYTE = UInt8*
  alias HANDLE = Void*
  alias HWND = Void*

  alias WPARAM = ULONG_PTR
  alias LPARAM = ULONG_PTR
  alias LPDWORD = DWORD*

  TRUE  = 1
  FALSE = 0
end
