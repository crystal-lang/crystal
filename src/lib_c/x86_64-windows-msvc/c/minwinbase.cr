# part of winbase
lib LibC
  struct OVERLAPPED_OFFSET
    offset : DWORD
    offsetHigh : DWORD
  end

  union OVERLAPPED_UNION
    offset : OVERLAPPED_OFFSET
    pointer : Void*
  end

  struct OVERLAPPED
    internal : ULONG_PTR
    internalHigh : ULONG_PTR
    union : OVERLAPPED_UNION
    hEvent : HANDLE
  end

  struct OVERLAPPED_ENTRY
    lpCompletionKey : ULONG_PTR
    lpOverlapped : OVERLAPPED*
    internal : ULONG_PTR
    dwNumberOfBytesTransferred : DWORD
  end

  struct FILETIME
    dwLowDateTime : DWORD
    dwHighDateTime : DWORD
  end

  struct SYSTEMTIME
    wYear : WORD
    wMonth : WORD
    wDayOfWeek : WORD
    wDay : WORD
    wHour : WORD
    wMinute : WORD
    wSecond : WORD
    wMilliseconds : WORD
  end

  enum GET_FILEEX_INFO_LEVELS
    GetFileExInfoStandard
    GetFileExMaxInfoLevel
  end

  enum FILE_INFO_BY_HANDLE_CLASS
    FileBasicInfo = 0
  end

  LOCKFILE_FAIL_IMMEDIATELY = DWORD.new(0x00000001)
  LOCKFILE_EXCLUSIVE_LOCK   = DWORD.new(0x00000002)

  STATUS_PENDING = 0x103
  STILL_ACTIVE   = STATUS_PENDING
end
