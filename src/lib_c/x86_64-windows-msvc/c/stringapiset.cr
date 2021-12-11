require "lib_c"
require "c/win_def"
require "c/winnt"

lib LibC
  # this is only for the `wmain` entry point where Crystal's standard library is
  # unusable, all other code should use `String.from_utf16` instead
  fun WideCharToMultiByte(
    codePage : DWORD, dwFlags : DWORD, lpWideCharStr : WCHAR*,
    cchWideChar : Int, lpMultiByteStr : LPSTR, cbMultiByte : Int,
    lpDefaultChar : CHAR*, lpUsedDefaultChar : BOOL*
  ) : Int
end
