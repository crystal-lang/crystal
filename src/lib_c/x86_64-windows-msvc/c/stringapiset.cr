require "lib_c"
require "c/win_def"
require "c/winnt"

lib LibC
  # this is only for the `wmain` entry point where Crystal's standard library is
  # unusable, all other code should use `String.from_utf16` instead
  fun WideCharToMultiByte(
    codePage : UInt, dwFlags : DWORD, lpWideCharStr : LPWSTR,
    cchWideChar : Int, lpMultiByteStr : LPSTR, cbMultiByte : Int,
    lpDefaultChar : CHAR*, lpUsedDefaultChar : BOOL*
  ) : Int

  # this is only for the delay-load helper, all other code should use
  # `String#to_utf16` instead
  fun MultiByteToWideChar(
    codePage : UInt, dwFlags : DWORD, lpMultiByteStr : LPSTR,
    cbMultiByte : Int, lpWideCharStr : LPWSTR, cchWideChar : Int
  ) : Int
end
