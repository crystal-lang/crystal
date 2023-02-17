require "./basetsd"
require "c/wtypesbase"

lib LibC
  CREATE_UNICODE_ENVIRONMENT = 0x00000400

  struct PROCESS_INFORMATION
    hProcess : HANDLE
    hThread : HANDLE
    dwProcessId : DWORD
    dwThreadId : DWORD
  end

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
    lpReserved2 : BYTE*
    hStdInput : HANDLE
    hStdOutput : HANDLE
    hStdError : HANDLE
  end

  struct NT_TIB
    exceptionList : Void*
    stackBase : Void*
    stackLimit : Void*
    subSystemTib : Void*
    fiberData : Void*
    arbitraryUserPointer : Void*
    pvSelf : NT_TIB*
  end

  fun NtCurrentTeb : NT_TIB*
  fun GetCurrentThread : HANDLE
  fun GetCurrentThreadId : DWORD
  fun GetCurrentThreadStackLimits(lowLimit : ULONG_PTR*, highLimit : ULONG_PTR*) : Void
  fun GetCurrentProcess : HANDLE
  fun GetCurrentProcessId : DWORD
  fun OpenProcess(dwDesiredAccess : DWORD, bInheritHandle : BOOL, dwProcessId : DWORD) : HANDLE
  fun GetExitCodeProcess(hProcess : HANDLE, lpExitCode : DWORD*) : BOOL
  fun TerminateProcess(hProcess : HANDLE, uExitCode : UInt) : BOOL
  fun CreateProcessW(lpApplicationName : LPWSTR, lpCommandLine : LPWSTR,
                     lpProcessAttributes : SECURITY_ATTRIBUTES*, lpThreadAttributes : SECURITY_ATTRIBUTES*,
                     bInheritHandles : BOOL, dwCreationFlags : DWORD,
                     lpEnvironment : Void*, lpCurrentDirectory : LPWSTR,
                     lpStartupInfo : STARTUPINFOW*, lpProcessInformation : PROCESS_INFORMATION*) : BOOL
  fun SetThreadStackGuarantee(stackSizeInBytes : DWORD*) : BOOL
  fun GetProcessTimes(hProcess : HANDLE, lpCreationTime : FILETIME*, lpExitTime : FILETIME*,
                      lpKernelTime : FILETIME*, lpUserTime : FILETIME*) : BOOL
  fun SwitchToThread : BOOL

  PROCESS_QUERY_INFORMATION = 0x0400
end
