require "c/basetsd"
require "c/int_safe"
require "c/winbase"
require "c/wtypesbase"

lib LibC
  # the meanings of these fields are documented not in the Win32 API docs but in
  # https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/displaying-a-critical-section
  struct CRITICAL_SECTION
    debugInfo : Void* # PRTL_CRITICAL_SECTION_DEBUG
    lockCount : LONG
    recursionCount : LONG
    owningThread : HANDLE
    lockSemaphore : HANDLE
    spinCount : UInt64
  end

  struct CONDITION_VARIABLE
    ptr : Void*
  end

  fun InitializeCriticalSectionAndSpinCount(lpCriticalSection : CRITICAL_SECTION*, dwSpinCount : DWORD) : BOOL
  fun DeleteCriticalSection(lpCriticalSection : CRITICAL_SECTION*)
  fun EnterCriticalSection(lpCriticalSection : CRITICAL_SECTION*)
  fun TryEnterCriticalSection(lpCriticalSection : CRITICAL_SECTION*) : BOOL
  fun LeaveCriticalSection(lpCriticalSection : CRITICAL_SECTION*)

  fun InitializeConditionVariable(conditionVariable : CONDITION_VARIABLE*)
  fun SleepConditionVariableCS(conditionVariable : CONDITION_VARIABLE*, criticalSection : CRITICAL_SECTION*, dwMilliseconds : DWORD) : BOOL
  fun WakeConditionVariable(conditionVariable : CONDITION_VARIABLE*)
  fun WakeAllConditionVariable(conditionVariable : CONDITION_VARIABLE*)

  fun Sleep(dwMilliseconds : DWORD)
  fun WaitForSingleObject(hHandle : HANDLE, dwMilliseconds : DWORD) : DWORD

  alias PTIMERAPCROUTINE = (Void*, DWORD, DWORD) ->
  CREATE_WAITABLE_TIMER_HIGH_RESOLUTION = 0x00000002_u32

  fun CreateWaitableTimerExW(lpTimerAttributes : SECURITY_ATTRIBUTES*, lpTimerName : LPWSTR, dwFlags : DWORD, dwDesiredAccess : DWORD) : HANDLE
  fun SetWaitableTimer(hTimer : HANDLE, lpDueTime : LARGE_INTEGER*, lPeriod : LONG, pfnCompletionRoutine : PTIMERAPCROUTINE*, lpArgToCompletionRoutine : Void*, fResume : BOOL) : BOOL
  fun CancelWaitableTimer(hTimer : HANDLE) : BOOL
end
