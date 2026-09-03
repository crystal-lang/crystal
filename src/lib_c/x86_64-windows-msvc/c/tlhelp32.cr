lib LibC
  TH32CS_SNAPPROCESS = 0x00000002

  struct PROCESSENTRY32W
    dwSize : DWORD
    cntUsage : DWORD
    th32ProcessID : DWORD
    th32DefaultHeapID : ULONG_PTR
    th32ModuleID : DWORD
    cntThreads : DWORD
    th32ParentProcessID : DWORD
    pcPriClassBase : LONG
    dwFlags : DWORD
    szExeFile : WCHAR[MAX_PATH]
  end

  fun CreateToolhelp32Snapshot(dwFlags : DWORD, th32ProcessID : DWORD) : HANDLE
  fun Process32FirstW(hSnapshot : HANDLE, lppe : PROCESSENTRY32W*) : BOOL
  fun Process32NextW(hSnapshot : HANDLE, lppe : PROCESSENTRY32W*) : BOOL
end
