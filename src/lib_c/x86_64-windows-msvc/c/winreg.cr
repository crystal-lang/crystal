lib LibC
  enum REGSAM
    # Combines the `STANDARD_RIGHTS_REQUIRED`, `QUERY_VALUE`, `SET_VALUE`, `CREATE_SUB_KEY`, `ENUMERATE_SUB_KEYS`, `NOTIFY`, and `CREATE_LINK` access rights.
    ALL_ACCESS = 0xf003f

    # Reserved for system use.
    CREATE_LINK = 0x00020

    # Required to create a subkey of a registry key.
    CREATE_SUB_KEY = 0x00004

    # Required to enumerate the subkeys of a registry key.
    ENUMERATE_SUB_KEYS = 0x00008

    # Equivalent to `READ`.
    EXECUTE = 0x20019

    # Required to request change notifications for a registry key or for subkeys of a registry key.
    NOTIFY = 0x00010

    # Required to query the values of a registry key.
    QUERY_VALUE = 0x00001

    # Combines the `STANDARD_RIGHTS_READ`, `QUERY_VALUE`, `ENUMERATE_SUB_KEYS`, and `NOTIFY` values.
    READ = 0x20019

    # Required to create, delete, or set a registry value.
    SET_VALUE = 0x00002

    # Indicates that an application on 64-bit Windows should operate on the 32-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_32KEY = 0x00200

    # Indicates that an application on 64-bit Windows should operate on the 64-bit registry view. This flag is ignored by 32-bit Windows.
    # This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
    # Windows 2000: This flag is not supported.
    WOW64_64KEY = 0x00100

    # Combines the STANDARD_RIGHTS_WRITE, `KEY_SET_VALUE`, and `KEY_CREATE_SUB_KEY` access rights.
    WRITE = 0x20006
  end

  enum ValueType
    NONE                       = 0
    SZ                         = 1
    EXPAND_SZ                  = 2
    BINARY                     = 3
    DWORD                      = 4
    DWORD_LITTLE_ENDIAN        = DWORD
    DWORD_BIG_ENDIAN           =  5
    LINK                       =  6
    MULTI_SZ                   =  7
    RESOURCE_LIST              =  8
    FULL_RESOURCE_DESCRIPTOR   =  9
    RESOURCE_REQUIREMENTS_LIST = 10
    QWORD                      = 11
    QWORD_LITTLE_ENDIAN        = QWORD
  end

  HKEY_CLASSES_ROOT     = Pointer(Void).new(0x80000000).as(HKEY)
  HKEY_CURRENT_USER     = Pointer(Void).new(0x80000001).as(HKEY)
  HKEY_LOCAL_MACHINE    = Pointer(Void).new(0x80000002).as(HKEY)
  HKEY_USERS            = Pointer(Void).new(0x80000003).as(HKEY)
  HKEY_PERFORMANCE_DATA = Pointer(Void).new(0x80000004).as(HKEY)
  HKEY_CURRENT_CONFIG   = Pointer(Void).new(0x80000005).as(HKEY)
  HKEY_DYN_DATA         = Pointer(Void).new(0x8000006).as(HKEY)

  enum RegOption
    NON_VOLATILE   = 0x00000000
    VOLATILE       = 0x00000001
    CREATE_LINK    = 0x00000002
    BACKUP_RESTORE = 0x00000004
  end

  enum RegDisposition : UInt32
    CREATED_NEW_KEY     = 0x00000001
    OPENED_EXISTING_KEY = 0x00000002
  end

  alias LSTATUS = DWORD
  fun RegOpenKeyExW(hKey : HKEY, lpSubKey : LPWSTR, ulOptions : DWORD, samDesired : REGSAM, phkResult : PHKEY) : LSTATUS
  fun RegCloseKey(hKey : HKEY) : LSTATUS
  fun RegCreateKeyExW(hKey : HKEY, lpSubKey : LPWSTR, reserved : DWORD, lpClass : LPWSTR, dwOptions : RegOption,
                      samDesired : REGSAM, lpSecurityAttributes : SECURITY_ATTRIBUTES*, phkResult : PHKEY, lpdwDisposition : LibC::RegDisposition*) : LSTATUS
  fun RegDeleteKeyExW(hKey : HKEY, lpSubKey : LPWSTR, samDesired : DWORD, reserved : DWORD) : DWORD

  fun RegQueryValueExW(hKey : HKEY, lpValueName : LPWSTR, lpReserved : LPDWORD, lpType : ValueType*, lpData : LPBYTE, lpcbData : LPDWORD) : LSTATUS
  fun RegQueryInfoKeyW(hKey : HKEY, lpClass : LPSTR, lpcchClass : LPDWORD, lpReserved : LPDWORD,
                       lpcSubKeys : LPDWORD, lpcbMaxSubKeyLen : LPDWORD,
                       lpcbMaxClassLen : LPDWORD,
                       lpcValues : LPDWORD, lpcbMaxValueNameLen : LPDWORD, lpcbMaxValueLen : LPDWORD,
                       lpcbSecurityDescriptor : LPDWORD, lpftLastWriteTime : FILETIME*) : DWORD
  fun RegSetValueExW(hKey : HKEY, lpValueName : LPWSTR, reserved : DWORD, dwType : DWORD, lpData : BYTE*, cbData : DWORD) : LSTATUS

  fun RegEnumValueW(hKey : HKEY, dwIndex : DWORD,
                    lpValueName : LPWSTR, lpcchValueName : LPDWORD,
                    lpReserved : LPDWORD, lpType : ValueType*,
                    lpData : LPBYTE, lpcbData : LPDWORD) : LSTATUS
  fun RegEnumKeyExW(hKey : HKEY, dwIndex : DWORD,
                    lpName : LPWSTR, lpcchName : LPDWORD,
                    lpReserved : LPDWORD,
                    lpClass : LPWSTR, lpcchClass : LPDWORD,
                    lpftLastWriteTime : FILETIME*) : LSTATUS
  fun RegLoadMUIStringW(
    hKey : HKEY,
    pszValue : LPWSTR,
    pszOutBuf : LPWSTR,
    cbOutBuf : DWORD,
    pcbData : LPDWORD,
    flags : DWORD,
    pszDirectory : LPWSTR
  ) : LSTATUS
end
