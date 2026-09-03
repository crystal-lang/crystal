require "./winnt"

lib LibC
  fun CreateJobObjectW(lpJobAttributes : SECURITY_ATTRIBUTES*, lpName : LPWSTR) : HANDLE
  fun SetInformationJobObject(hJob : HANDLE, jobObjectInformationClass : JOBOBJECTINFOCLASS, lpJobObjectInformation : Void*, cbJobObjectInformationLength : DWORD) : BOOL
  fun AssignProcessToJobObject(hJob : HANDLE, hProcess : HANDLE) : BOOL
end
