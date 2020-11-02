lib LibC
  alias BOOLEAN = BYTE
  alias LONG = Int32
  alias INT = Int32
  alias VOID = Void
  alias PVOID = Void*
  alias LPCVOID = Void*
  alias UCHAR = UChar
  alias SHORT = Short
  alias USHORT = UShort
  alias ULONG = UInt32

  alias CHAR = UChar
  alias PCHAR = CHAR*
  alias WCHAR = UInt16
  alias LPSTR = CHAR*
  alias PSTR = CHAR*
  alias PCSTR = CHAR*
  alias LPWSTR = WCHAR*
  alias LPWCH = WCHAR*

  alias HANDLE = Void*
  alias HMODULE = Void*

  INVALID_FILE_ATTRIBUTES      = DWORD.new!(-1)
  FILE_ATTRIBUTE_DIRECTORY     =  0x10
  FILE_ATTRIBUTE_READONLY      =   0x1
  FILE_ATTRIBUTE_REPARSE_POINT = 0x400

  FILE_READ_ATTRIBUTES  =   0x80
  FILE_WRITE_ATTRIBUTES = 0x0100

  # Memory protection constants
  PAGE_READWRITE = 0x04

  PROCESS_QUERY_LIMITED_INFORMATION =     0x1000
  SYNCHRONIZE                       = 0x00100000

  DUPLICATE_CLOSE_SOURCE = 0x00000001
  DUPLICATE_SAME_ACCESS  = 0x00000002
end
