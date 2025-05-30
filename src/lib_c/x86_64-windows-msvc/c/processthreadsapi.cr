require "./basetsd"
require "c/wtypesbase"
require "c/sdkddkver"

lib LibC
  CREATE_SUSPENDED           = 0x00000004
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

  fun NtCurrentTeb : NT_TIB*
  fun GetCurrentThread : HANDLE
  fun GetCurrentThreadId : DWORD
  {% if LibC::WIN32_WINNT >= LibC::WIN32_WINNT_WIN8 %}
    fun GetCurrentThreadStackLimits(lowLimit : ULONG_PTR*, highLimit : ULONG_PTR*) : Void
  {% end %}
  fun GetCurrentProcess : HANDLE
  fun GetCurrentProcessId : DWORD
  fun OpenProcess(dwDesiredAccess : DWORD, bInheritHandle : BOOL, dwProcessId : DWORD) : HANDLE
  fun GetExitCodeProcess(hProcess : HANDLE, lpExitCode : DWORD*) : BOOL
  fun ExitProcess(uExitCode : UInt) : NoReturn
  fun TerminateProcess(hProcess : HANDLE, uExitCode : UInt) : BOOL
  fun CreateProcessW(lpApplicationName : LPWSTR, lpCommandLine : LPWSTR,
                     lpProcessAttributes : SECURITY_ATTRIBUTES*, lpThreadAttributes : SECURITY_ATTRIBUTES*,
                     bInheritHandles : BOOL, dwCreationFlags : DWORD,
                     lpEnvironment : Void*, lpCurrentDirectory : LPWSTR,
                     lpStartupInfo : STARTUPINFOW*, lpProcessInformation : PROCESS_INFORMATION*) : BOOL
  {% if LibC::WIN32_WINNT >= LibC::WIN32_WINNT_WIN10 %}
    fun SetThreadDescription(hThread : HANDLE, lpThreadDescription : LPWSTR) : LONG
  {% end %}
  fun SetThreadStackGuarantee(stackSizeInBytes : DWORD*) : BOOL
  fun GetProcessTimes(hProcess : HANDLE, lpCreationTime : FILETIME*, lpExitTime : FILETIME*,
                      lpKernelTime : FILETIME*, lpUserTime : FILETIME*) : BOOL
  fun SwitchToThread : BOOL
  fun QueueUserAPC(pfnAPC : PAPCFUNC, hThread : HANDLE, dwData : ULONG_PTR) : DWORD

  fun GetThreadContext(hThread : HANDLE, lpContext : CONTEXT*) : DWORD
  fun ResumeThread(hThread : HANDLE) : DWORD
  fun SuspendThread(hThread : HANDLE) : DWORD

  TLS_OUT_OF_INDEXES = 0xFFFFFFFF_u32

  fun TlsAlloc : DWORD
  fun TlsGetValue(dwTlsIndex : DWORD) : Void*
  fun TlsSetValue(dwTlsIndex : DWORD, lpTlsValue : Void*) : BOOL

  PROCESS_QUERY_INFORMATION = 0x0400
end
