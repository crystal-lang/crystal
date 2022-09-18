require "c/winnt"

lib LibC
  struct SECURITY_ATTRIBUTES
    nLength : DWORD
    lpSecurityDescriptor : Void*
    bInheritHandle : BOOL
  end
end
