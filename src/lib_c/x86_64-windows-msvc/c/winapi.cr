lib LibC
  STD_INPUT_HANDLE  = 0xFFFFFFF6_u32
  STD_OUTPUT_HANDLE = 0xFFFFFFF5_u32
  STD_ERROR_HANDLE  = 0xFFFFFFF4_u32

  FILE_TYPE_UNKNOWN = 0x0000
  FILE_TYPE_DISK    = 0x0001
  FILE_TYPE_CHAR    = 0x0002
  FILE_TYPE_PIPE    = 0x0003
  FILE_TYPE_REMOTE  = 0x8000

  GENERIC_EXECUTE = 0x20000000
  GENERIC_WRITE   = 0x40000000
  GENERIC_READ    = 0x80000000

  CREATE_NEW        = 1
  CREATE_ALWAYS     = 2
  OPEN_EXISTING     = 3
  OPEN_ALWAYS       = 4
  TRUNCATE_EXISTING = 5

  FILE_FLAG_OVERLAPPED = 0x40000000

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx
  alias Long = Int32
  alias Word = UInt16
  alias WChar = UInt16
  alias DWord = UInt32
  alias Handle = Void*
  alias SizeT = UInt64
  alias BOOL = Int32 # FIXME maybe it need to be removed because it can be confused with Bool

  INVALID_HANDLE_VALUE = Pointer(Void).new((-1).to_u64)
  INFINITY             = 0xFFFFFFFF_u32

  fun _DuplicateHandle = DuplicateHandle(source_process : Handle, source : Handle, target_process : Handle, target : Handle*, desired_access : DWord, inherit_handle : Bool, options : DWord) : Bool

  # member names are not original otherwise they would be really confusing
  struct OVERLAPPED
    status : SizeT
    bytes_transfered : SizeT
    offset : UInt64
    event : Handle
  end

  struct SECURITY_ATTRIBUTES
    nLength : DWord
    lpSecurityDescriptor : Void*
    bInheritHandle : BOOL
  end

  fun _GetStdHandle = GetStdHandle(std_handle : DWord) : Handle
  fun _GetFileType = GetFileType(file : Handle) : DWord
  fun _CreateFileA = CreateFileA(filename : UInt8*, access : DWord, sharemode : DWord, security_attributes : SECURITY_ATTRIBUTES*, creation : DWord, flags : DWord, template : Handle) : Handle
  fun _ReadFile = ReadFile(file : Handle, buffer : UInt8*, size : DWord, read : DWord*, overlapped : OVERLAPPED*) : Bool
  fun _WriteFile = WriteFile(file : Handle, buffer : UInt8*, size : DWord, written : DWord*, overlapped : OVERLAPPED*) : Bool
  fun _CloseHandle = CloseHandle(file : Handle) : Bool

  fun _GetCurrentDirectoryA = GetCurrentDirectoryA(size : DWord, buffer : UInt8*) : DWord
  fun _SetCurrentDirectoryA = SetCurrentDirectoryA(path : UInt8*) : BOOL
  fun _CreateDirectoryA = CreateDirectoryA(path : UInt8*, security_attribute : Void*) : BOOL
  fun _RemoveDirectoryA = RemoveDirectoryA(path : UInt8*) : BOOL
  fun _GetTempPathA = GetTempPathA(len : DWord, buffer : UInt8*) : DWord

  MAX_PATH = 260

  struct FILETIME
    dwLowDateTime : DWord
    dwHighDateTime : DWord
  end

  struct WIN32_FIND_DATA_A
    dwFileAttributes : DWord
    ftCreationTime : FILETIME
    ftLastAccessTime : FILETIME
    ftLastWriteTime : FILETIME
    nFileSizeHigh : DWord
    nFileSizeLow : DWord
    dwReserved0 : DWord
    dwReserved1 : DWord
    cFileName : StaticArray(UInt8, MAX_PATH)
    cAlternateFileName : StaticArray(UInt8, 14)
  end

  FILE_ATTRIBUTE_ARCHIVE       =   32_i32
  FILE_ATTRIBUTE_COMPRESSED    = 2048_i32
  FILE_ATTRIBUTE_NORMAL        =  128_i32
  FILE_ATTRIBUTE_DIRECTORY     =   16_i32
  FILE_ATTRIBUTE_HIDDEN        =    2_i32
  FILE_ATTRIBUTE_READONLY      =    1_i32
  FILE_ATTRIBUTE_REPARSE_POINT = 1024_i32
  FILE_ATTRIBUTE_SYSTEM        =    4_i32
  FILE_ATTRIBUTE_TEMPORARY     =  256_i32
  INVALID_FILE_ATTRIBUTES      =   -1_i32

  FILE_BEGIN               = 0_i32
  FILE_CURRENT             = 1_i32
  FILE_END                 = 2_i32
  INVALID_SET_FILE_POINTER = (-1).to_u32

  fun _FindFirstFileA = FindFirstFileA(fileName : UInt8*, filedata : WIN32_FIND_DATA_A*) : Handle
  fun _FindNextFileA = FindNextFileA(file : Handle, filedata : WIN32_FIND_DATA_A*) : BOOL
  fun _FindClose = FindClose(file : Handle) : BOOL
  fun _GetFileAttributesA = GetFileAttributesA(filename : UInt8*) : DWord
  fun _GetFileSize = GetFileSize(file : Handle, fileSizeHigh : DWord*) : DWord
  fun _GetFileSizeEx = GetFileSizeEx(file : Handle, size : UInt64*) : BOOL
  fun _GetFileTime = GetFileTime(file : Handle, lpCreationTime : FILETIME*, lpLastAccessTime : FILETIME*, lpLastWriteTime : FILETIME*) : BOOL
  fun _SetFilePointer = SetFilePointer(file : Handle, lDistanceToMove : Long, lpDistanceToMoveHigh : Long*, dwMoveMethod : DWord) : DWord
  fun _SetEndOfFile = SetEndOfFile(file : Handle) : BOOL
  fun _DeleteFileA = DeleteFileA(filename : UInt8*) : BOOL
  fun _GetFullPathNameA = GetFullPathNameA(filename : UInt8*, buf_len : DWord, lpBuffer : UInt8*, lpFilePart : UInt8**) : DWord
  # from Shlwapi.lib
  # fun _PathFileExistsA = PathFileExistsA(path : UInt8*) : BOOL
  fun _MoveFileA = MoveFileA(lpExistingFileName : UInt8*, lpNewFileName : UInt8*) : BOOL
  fun _GetTempFileNameA = GetTempFileNameA(path_name : UInt8*, prefix : UInt8*, unique_num : UInt32, temp_file_name : UInt8*) : UInt32

  fun _CreateIoCompletionPort = CreateIoCompletionPort(file : Handle, port : Handle, data : Void*, threads : DWord) : Handle
  fun _GetQueuedCompletionStatus = GetQueuedCompletionStatus(port : Handle, bytes_transfered : DWord*, data : Void**, entry : OVERLAPPED**, timeout_millis : DWord) : Bool
  fun _PostQueuedCompletionStatus = PostQueuedCompletionStatus(port : Handle, bytes_transfered : DWord, data : Void*, entry : OVERLAPPED*) : Bool
  fun _GetCurrentProcess = GetCurrentProcess : Handle
  fun _GetCurrentThread = GetCurrentThread : Handle
  fun _CreatePipe = CreatePipe(hReadPipe : UInt64*, hWritePipe : UInt64*, lpPipeAttributes : SECURITY_ATTRIBUTES*, nSize : DWord) : BOOL
  fun _PeekNamedPipe = PeekNamedPipe(hNamedPipe : Handle, lpBuffer : UInt8*, nBufferSize : DWord, lpBytesRead : DWord*, lpTotalBytesAvail : DWord*, lpBytesLeftThisMessage : DWord*) : BOOL

  WAIT_ABANDONED = 0x00000080_u32
  WAIT_OBJECT_0  = 0x00000000_u32
  WAIT_TIMEOUT   = 0x00000102_u32
  WAIT_FAILED    = 0xFFFFFFFF_u32

  fun _WaitForSingleObject = WaitForSingleObject(handle : Handle, timeout_millis : DWord) : DWord
  fun _CreateTimerQueueTimer = CreateTimerQueueTimer(timer_handle : Handle*, queue_handle : Handle, callback : (Void*, Bool) ->, data : Void*, due : DWord, period : DWord, flags : SizeT) : Bool
  fun _DeleteTimerQueueTimer = DeleteTimerQueueTimer(queue_handle : Handle, timer_handle : Handle, completion_event : Handle) : Bool
  fun _GetLastError = GetLastError : DWord
  fun _SetLastError = SetLastError(code : DWord) : Void

  # STARTUPINFOA.deFlags
  STARTF_USESTDHANDLES = 0x00000100_u32

  # CreateProcessA.dwCreationFlags
  NORMAL_PRIORITY_CLASS = 0x00000020_u32
  CREATE_NO_WINDOW      = 0x08000000_u32

  struct STARTUPINFOA
    cb : DWord
    lpReserved : UInt8*
    lpDesktop : UInt8*
    lpTitle : UInt8*
    dwX : DWord
    dwY : DWord
    dwXSize : DWord
    dwYSize : DWord
    dwXCountChars : DWord
    dwYCountChars : DWord
    dwFillAttribute : DWord
    dwFlags : DWord
    wShowWindow : Word
    cbReserved2 : Word
    lpReserved2 : UInt8*
    hStdInput : Handle
    hStdOutput : Handle
    hStdError : Handle
  end

  struct PROCESS_INFORMATION
    hProcess : Handle
    hThread : Handle
    dwProcessId : DWord
    dwThreadId : DWord
  end

  fun _CreateProcessA = CreateProcessA(lpApplicationName : UInt8*, lpCommandLine : UInt8*,
                                       lpProcessAttributes : SECURITY_ATTRIBUTES*, lpThreadAttributes : SECURITY_ATTRIBUTES*, bInheritHandles : BOOL,
                                       dwCreationFlags : DWord, lpEnvironment : Void*, lpCurrentDirectory : UInt8*,
                                       lpStartupInfo : STARTUPINFOA*, lpProcessInformation : PROCESS_INFORMATION*) : BOOL
  fun _KillProcess = KillProcess(hProcess : Handle, uExitCode : UInt32) : BOOL
  fun _GetExitCodeProcess = GetExitCodeProcess(hProcess : Handle, lpExitCode : DWord*) : BOOL

  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32

  fun _FormatMessageA = FormatMessageA(flags : DWord, source : Void*, msg : DWord, lang : DWord, buffer : UInt8*, size : DWord, args : Void*) : DWord

  WSASYSNOTREADY     = 10091
  WSAVERNOTSUPPORTED = 10092
  WSAEINPROGRESS     = 10036
  WSAEPROCLIM        = 10067
  WSAEFAULT          = 10014
  WSAEINVAL          = 10022

  struct WSAData
    wVersion : UInt16
    wHighVersion : UInt16
    szDescription : UInt8[257]
    szSystemStatus : UInt8[129]
    iMaxSockets : UInt16
    iMaxUdpDg : UInt16
    lpVendorInfo : UInt8*
  end

  fun _WSAStartup = WSAStartup(version : Int16, data : WSAData*) : Int32

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/ms724950(v=vs.85).aspx
  struct SystemTime
    wYear : Word
    wMonth : Word
    wDayOfWeek : Word
    wDay : Word
    wHour : Word
    wMinute : Word
    wSecond : Word
    wMilliseconds : Word
  end

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/ms725481(v=vs.85).aspx
  struct TIME_ZONE_INFORMATION
    _Bias : Long
    _StandardName : StaticArray(WChar, 32)
    _StandardDate : SYSTEMTIME
    _StandardBias : Long
    _DaylightName : StaticArray(WChar, 32)
    _DaylightDate : SYSTEMTIME
    _DaylightBias : Long
  end

  fun _GetTimeZoneInformation = GetTimeZoneInformation(tz_info : TIME_ZONE_INFORMATION*) : DWord
  fun _GetSystemTimeAsFileTime = GetSystemTimeAsFileTime(time : FILETIME*)

  fun _GetComputerNameA = GetComputerNameA(buffer : UInt8*, size : DWord*) : BOOL

  fun _CxxThrowException = _CxxThrowException(exception_object : Void*, throw_info : Void*) : NoReturn
end

module WindowsExt
  @[Primitive(:throw_info)]
  def self.throw_info : Void*
  end
end
