# part of winbase
lib LibC
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

  STATUS_PENDING = 0x103
  STILL_ACTIVE   = STATUS_PENDING
end
