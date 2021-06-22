require "c/winnt"

lib LibC
  INVALID_HANDLE_VALUE = HANDLE.new(-1)

  fun CloseHandle(hObject : HANDLE) : BOOL

  fun DuplicateHandle(hSourceProcessHandle : HANDLE, hSourceHandle : HANDLE,
                      hTargetProcessHandle : HANDLE, lpTargetHandle : HANDLE*,
                      dwDesiredAccess : DWORD, bInheritHandle : BOOL, dwOptions : DWORD) : BOOL
end
