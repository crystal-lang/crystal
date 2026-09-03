require "c/winnt"

@[Link("userenv")]
lib LibC
  fun GetProfilesDirectoryW(lpProfileDir : LPWSTR, lpcchSize : DWORD*) : BOOL
end
