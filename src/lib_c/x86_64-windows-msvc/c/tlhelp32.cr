require "./basetsd"

# TlHelp32.h
@[Link("Kernel32")]
lib LibC
  TH32CS_SNAPPROCESS = 0x00000002

  struct PROCESSENTRY32
    dwSize : DWORD
    cntUsage : DWORD
    th32ProcessID : DWORD
    th32DefaultHeapID : ULONG_PTR
    th32ModuleID : DWORD
    cntThreads : DWORD
    th32ParentProcessID : DWORD
    pcPriClassBase : LONG
    dwFlags : DWORD
    szExeFile : CHAR[MAX_PATH]
  end

  fun CreateToolhelp32Snapshot(
    dwFlags : DWORD,
    th32ProcessID : DWORD
  ) : HANDLE

  fun Process32First(
    hSnapshot : HANDLE,
    lppe : PROCESSENTRY32*
  ) : BOOL

  fun Process32Next(
    hSnapshot : HANDLE,
    lppe : PROCESSENTRY32*
  ) : BOOL
end
