require "c/winnt"

@[Link("kernel32")]
lib LibC
  fun GetStdHandle(nStdHandle : DWORD) : HANDLE

  fun GetCurrentDirectoryW(nBufferLength : DWORD, lpBuffer : LPWSTR) : DWORD
  fun SetCurrentDirectoryW(lpPathname : LPWSTR) : BOOL

  fun GetEnvironmentVariableW(lpName : LPWSTR, lpBuffer : LPWSTR, nSize : DWORD) : DWORD
  fun GetEnvironmentStringsW : LPWCH
  fun FreeEnvironmentStringsW(lpszEnvironmentBlock : LPWCH) : BOOL
  fun SetEnvironmentVariableW(lpName : LPWSTR, lpValue : LPWSTR) : BOOL
end
