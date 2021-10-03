require "c/int_safe"

lib LibC
  alias BOOLEAN = BYTE
  alias LONG = Int32
  alias LARGE_INTEGER = Int64

  alias CHAR = UChar
  alias WCHAR = UInt16
  alias LPSTR = CHAR*
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

  enum REGSAM
    # Required to query the values of a registry key.
    QUERY_VALUE = 0x0001

    # Required to create, delete, or set a registry value.
    SET_VALUE = 0x0002

    # Required to create a subkey of a registry key.
    CREATE_SUB_KEY = 0x0004

    # Required to enumerate the subkeys of a registry key.
    ENUMERATE_SUB_KEYS = 0x0008

    # Required to request change notifications for a registry key or for subkeys of a registry key.
    NOTIFY = 0x0010

    # Reserved for system use.
    CREATE_LINK = 0x0020

    # Indicates that an application on 64-bit Windows should operate on the 32-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_32KEY = 0x0200

    # Indicates that an application on 64-bit Windows should operate on the 64-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_64KEY = 0x0100

    WOW64_RES = 0x0300

    # Combines the `STANDARD_RIGHTS_READ`, `QUERY_VALUE`, `ENUMERATE_SUB_KEYS`, and `NOTIFY` values.
    # (STANDARD_RIGHTS_READ | QUERY_VALUE | ENUMERATE_SUB_KEYS | NOTIFY) & ~SYNCHRONIZE
    READ = 0x20019

    # Combines the `STANDARD_RIGHTS_REQUIRED`, `QUERY_VALUE`, `SET_VALUE`, `CREATE_SUB_KEY`, `ENUMERATE_SUB_KEYS`, `NOTIFY`, and `CREATE_LINK` access rights.
    # (STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & ~SYNCHRONIZE
    ALL_ACCESS = 0xf003f

    # Equivalent to `READ`.
    # KEY_READ & ~SYNCHRONIZE
    EXECUTE = 0x20019

    # Combines the STANDARD_RIGHTS_WRITE, `KEY_SET_VALUE`, and `KEY_CREATE_SUB_KEY` access rights.
    # (STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & ~SYNCHRONIZE
    WRITE = 0x20006
  end
end
