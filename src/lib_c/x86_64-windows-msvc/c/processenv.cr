require "c/winnt"

lib LibC
  fun GetCurrentDirectoryW(nBufferLength : DWORD, lpBuffer : LPWSTR) : DWORD
  fun SetCurrentDirectoryW(lpPathname : LPWSTR) : BOOL

  fun GetEnvironmentVariableW(lpName : LPWSTR, lpBuffer : LPWSTR, nSize : DWORD) : DWORD
  fun GetEnvironmentStringsW : LPWCH
  fun FreeEnvironmentStringsW(lpszEnvironmentBlock : LPWCH) : BOOL
  fun SetEnvironmentVariableW(lpName : LPWSTR, lpValue : LPWSTR) : BOOL
end
