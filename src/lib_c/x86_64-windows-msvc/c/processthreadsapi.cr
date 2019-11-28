require "./basetsd"

lib LibC
  fun GetCurrentThreadStackLimits(lowLimit : ULONG_PTR*, highLimit : ULONG_PTR*) : Void
  fun ExitProcess(uExitCode : UINT) : NoReturn
  fun GetCurrentProcessId : DWORD
  fun GetCurrentProcess : HANDLE
  fun GetCurrentThread : HANDLE
  fun TerminateProcess(hProcess : HANDLE, uExitCode : UINT) : BOOL

  CREATE_SUSPENDED           = 0x00000004_u32
  DETACHED_PROCESS           = 0x00000008_u32
  CREATE_UNICODE_ENVIRONMENT = 0x00000400_u32
  CREATE_NO_WINDOW           = 0x08000000_u32

  struct PROCESS_INFORMATION
    hProcess : HANDLE
    hThread : HANDLE
    dwProcessId : DWORD
    dwThreadId : DWORD
  end

  alias LPPROCESS_INFORMATION = PROCESS_INFORMATION*

  STARTF_USESTDHANDLES         = 0x00000100_u32
  EXTENDED_STARTUPINFO_PRESENT = 0x00080000_u32

  struct STARTUPINFOW
    cb : DWORD
    lpReserved : LPWSTR
    lpDesktop : LPWSTR
    lpTitle : LPWSTR
    dwX : DWORD
    dwY : DWORD
    dwXSize : DWORD
    dwYSize : DWORD
    dwXCountChars : DWORD
    dwYCountChars : DWORD
    dwFillAttribute : DWORD
    dwFlags : DWORD
    wShowWindow : WORD
    cbReserved2 : WORD
    lpReserved2 : LPBYTE
    hStdInput : HANDLE
    hStdOutput : HANDLE
    hStdError : HANDLE
  end

  alias LPROC_THREAD_ATTRIBUTE_LIST = Void*
  PROC_THREAD_ATTRIBUTE_HANDLE_LIST = 0x00020002_u32

  struct STARTUPINFOEXW
    startupInfo : STARTUPINFOW
    lpAttributeList : LPROC_THREAD_ATTRIBUTE_LIST
  end

  fun InitializeProcThreadAttributeList(
    lpAttributeList : LPROC_THREAD_ATTRIBUTE_LIST,
    dwAttributeCount : DWORD,
    dwFlags : DWORD,
    lpSize : SIZE_T*
  ) : BOOL

  fun UpdateProcThreadAttribute(
    lpAttributeList : LPROC_THREAD_ATTRIBUTE_LIST,
    dwFlags : DWORD,
    attribute : DWORD,
    lpValue : PVOID,
    cbSize : SIZE_T,
    lpPreviousValue : PVOID,
    lpReturnSize : SIZE_T*
  ) : BOOL

  alias LPSTARTUPINFOW = Void*

  fun CreateProcessW(
    lpApplicationName : LPWSTR,
    lpCommandLine : LPWSTR,
    lpProcessAttributes : SECURITY_ATTRIBUTES*,
    lpThreadAttributes : SECURITY_ATTRIBUTES*,
    bInheritHandles : BOOL,
    dwCreationFlags : DWORD,
    lpEnvironment : LPVOID,
    lpCurrentDirectory : LPCWSTR,
    lpStartupInfo : LPSTARTUPINFOW,
    lpProcessInformation : LPPROCESS_INFORMATION
  ) : BOOL

  fun GetExitCodeProcess(
    hProcess : HANDLE,
    lpExitCode : DWORD*
  ) : BOOL

  PROCESS_QUERY_INFORMATION = 0x0400

  fun OpenProcess(
    dwDesiredAccess : DWORD,
    bInheritHandle : BOOL,
    dwProcessId : DWORD
  ) : HANDLE
end
