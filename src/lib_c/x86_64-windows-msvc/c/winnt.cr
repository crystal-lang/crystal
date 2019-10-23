lib LibC
  alias BOOLEAN = BYTE
  alias LONG = Int32

  alias CHAR = UChar
  alias WCHAR = UInt16
  alias LPSTR = CHAR*
  alias LPWSTR = WCHAR*
  alias LPWCH = WCHAR*

  alias HANDLE = Void*

  INVALID_FILE_ATTRIBUTES      = DWORD.new(-1)
  FILE_ATTRIBUTE_DIRECTORY     =  0x10
  FILE_ATTRIBUTE_READONLY      =   0x1
  FILE_ATTRIBUTE_REPARSE_POINT = 0x400

  FILE_READ_ATTRIBUTES = 0x80

  # Memory protection constants
  PAGE_READWRITE = 0x04
end
