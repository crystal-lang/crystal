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

  alias LPTHREAD_START_ROUTINE = Void* -> DWORD

  CREATE_SUSPENDED = 0x00000004

  fun GetCurrentThread : HANDLE
  fun GetCurrentThreadStackLimits(lowLimit : ULONG_PTR*, highLimit : ULONG_PTR*) : Void
  fun GetCurrentProcess : HANDLE
  fun GetCurrentProcessId : DWORD
  fun OpenProcess(dwDesiredAccess : DWORD, bInheritHandle : BOOL, dwProcessId : DWORD) : HANDLE
  fun GetExitCodeProcess(hProcess : HANDLE, lpExitCode : DWORD*) : BOOL
  fun CreateProcessW(lpApplicationName : LPWSTR, lpCommandLine : LPWSTR,
                     lpProcessAttributes : SECURITY_ATTRIBUTES*, lpThreadAttributes : SECURITY_ATTRIBUTES*,
                     bInheritHandles : BOOL, dwCreationFlags : DWORD,
                     lpEnvironment : Void*, lpCurrentDirectory : LPWSTR,
                     lpStartupInfo : STARTUPINFOW*, lpProcessInformation : PROCESS_INFORMATION*) : BOOL
  fun CreateThread(lpThreadAttributes : SECURITY_ATTRIBUTES*, dwStackSize : SizeT,
                   lpStartAddress : LPTHREAD_START_ROUTINE, lpParameter : Void*,
                   dwCreationFlags : DWORD, lpThreadId : DWORD*) : HANDLE
  fun ResumeThread(hThread : HANDLE) : DWORD
  fun GetProcessTimes(hProcess : HANDLE, lpCreationTime : FILETIME*, lpExitTime : FILETIME*,
                      lpKernelTime : FILETIME*, lpUserTime : FILETIME*) : BOOL

  PROCESS_QUERY_INFORMATION = 0x0400
end
