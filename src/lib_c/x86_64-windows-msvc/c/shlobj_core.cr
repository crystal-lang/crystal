require "c/guiddef"

@[Link("shell32")]
lib LibC
  fun SHGetKnownFolderPath(rfid : GUID*, dwFlags : DWORD, hToken : HANDLE, ppszPath : LPWSTR*) : DWORD
end
