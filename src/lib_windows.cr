@[CallConvention("X86_StdCall")]
lib LibWindows
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

  fun duplicate_handle = DuplicateHandle(source_process : Handle, source : Handle, target_process : Handle, target : Handle*, desired_access : DWord, inherit_handle : Bool, options : DWord) : Bool

  struct Overlapped
    status : SizeT
    bytes_transfered : SizeT
    offset : UInt64
    event : Handle
  end

  struct SecurityAttributes
    length : DWord
    security_descriptors : Void*
    inherit_handle : BOOL
  end

  fun get_std_handle = GetStdHandle(std_handle : DWord) : Handle
  fun get_file_type = GetFileType(file : Handle) : DWord
  fun create_file = CreateFileA(filename : UInt8*, access : DWord, sharemode : DWord, security_attributes : SecurityAttributes*, creation : DWord, flags : DWord, template : Handle) : Handle
  fun read_file = ReadFile(file : Handle, buffer : UInt8*, size : DWord, read : DWord*, overlapped : Overlapped*) : Bool
  fun write_file = WriteFile(file : Handle, buffer : UInt8*, size : DWord, written : DWord*, overlapped : Overlapped*) : Bool
  fun close_handle = CloseHandle(file : Handle) : Bool

  fun get_current_directory = GetCurrentDirectoryA(size : DWord,  buffer : UInt8*) : DWord
  fun set_current_directory = SetCurrentDirectoryA(path : UInt8*) : BOOL
  fun create_directory = CreateDirectoryA(path : UInt8*, security_attribute : Void*): BOOL
  fun remove_directory = RemoveDirectoryA(path : UInt8*) : BOOL
  fun get_temp_path = GetTempPathA(len : DWord, buffer : UInt8*) : DWord

  MAX_PATH = 260

  struct FILETIME
    dwLowDateTime : DWord
    dwHighDateTime : DWord
  end
  
  struct WIN32_FIND_DATA_A
    dwFileAttributes: DWord
    ftCreationTime: FILETIME
    ftLastAccessTime: FILETIME
    ftLastWriteTime: FILETIME
    nFileSizeHigh: DWord
    nFileSizeLow: DWord
    dwReserved0: DWord
    dwReserved1: DWord
    cFileName: StaticArray(UInt8, MAX_PATH)
    cAlternateFileName: StaticArray(UInt8, 14)
  end

  FILE_ATTRIBUTE_ARCHIVE        = 32_i32
  FILE_ATTRIBUTE_COMPRESSED     = 2048_i32
  FILE_ATTRIBUTE_NORMAL         = 128_i32
  FILE_ATTRIBUTE_DIRECTORY      = 16_i32
  FILE_ATTRIBUTE_HIDDEN         = 2_i32
  FILE_ATTRIBUTE_READONLY       = 1_i32
  FILE_ATTRIBUTE_REPARSE_POINT  = 1024_i32
  FILE_ATTRIBUTE_SYSTEM         = 4_i32
  FILE_ATTRIBUTE_TEMPORARY      = 256_i32
  INVALID_FILE_ATTRIBUTES       = -1_i32
  
  FILE_BEGIN                    = 0_i32
  FILE_CURRENT                  = 1_i32
  FILE_END                      = 2_i32
  INVALID_SET_FILE_POINTER      = (-1).to_u32

  fun find_first_file = FindFirstFileA(fileName: UInt8*, filedata: WIN32_FIND_DATA_A*) : Handle
  fun find_next_file = FindNextFileA(file: Handle, filedata: WIN32_FIND_DATA_A*) : BOOL
  fun find_close = FindClose(file: Handle) : BOOL
  fun get_file_attributes = GetFileAttributesA(filename : UInt8*) : DWord;
  fun get_file_size = GetFileSize(file : Handle, fileSizeHigh : DWord*) : DWord
  fun get_file_size_ex = GetFileSizeEx(file : Handle, size : UInt64*) : BOOL
  fun get_file_time = GetFileTime(file : Handle, lpCreationTime : FILETIME*, lpLastAccessTime : FILETIME*, lpLastWriteTime : FILETIME*) : BOOL
  fun set_file_pointer = SetFilePointer(file : Handle, lDistanceToMove : Long, lpDistanceToMoveHigh : Long*, dwMoveMethod : DWord) : DWord
  fun set_end_of_file = SetEndOfFile(file : Handle) : BOOL
  fun delete_file = DeleteFileA(filename : UInt8*) : BOOL
  fun get_full_path_name = GetFullPathNameA(filename : UInt8*, buf_len : DWord, lpBuffer : UInt8*, lpFilePart : UInt8**) : DWord
  # from Shlwapi.lib
  # fun path_file_dir_exists = PathFileExistsA(path : UInt8*) : BOOL
  fun move_file = MoveFileA(lpExistingFileName : UInt8*, lpNewFileName : UInt8*) : BOOL
  fun get_temp_file_name = GetTempFileNameA(path_name : UInt8*, prefix : UInt8*, unique_num : UInt32, temp_file_name : UInt8*) : UInt32

  fun create_io_completion_port = CreateIoCompletionPort(file : Handle, port : Handle, data : Void*, threads : DWord) : Handle
  fun get_queued_completion_status = GetQueuedCompletionStatus(port : Handle, bytes_transfered : DWord*, data : Void**, entry : Overlapped**, timeout_millis : DWord) : Bool
  fun post_queued_completion_status = PostQueuedCompletionStatus(port : Handle, bytes_transfered : DWord, data : Void*, entry : Overlapped*) : Bool
  fun get_current_process = GetCurrentProcess : Handle
  fun get_current_thread = GetCurrentThread : Handle
  fun create_pipe = CreatePipe(hReadPipe : UInt64*, hWritePipe : UInt64*, lpPipeAttributes : SecurityAttributes*, nSize : DWord) : BOOL
  fun peek_named_pipe = PeekNamedPipe(hNamedPipe : Handle, lpBuffer : UInt8*, nBufferSize : DWord, lpBytesRead : DWord*, lpTotalBytesAvail : DWord*, lpBytesLeftThisMessage : DWord*) : BOOL

  WAIT_ABANDONED = 0x00000080_u32
  WAIT_OBJECT_0  = 0x00000000_u32
  WAIT_TIMEOUT   = 0x00000102_u32
  WAIT_FAILED    = 0xFFFFFFFF_u32

  fun wait_for_single_object = WaitForSingleObject(handle : Handle, timeout_millis : DWord) : DWord
  fun create_timer_queue_timer = CreateTimerQueueTimer(timer_handle : Handle*, queue_handle : Handle, callback : (Void*, Bool) ->, data : Void*, due : DWord, period : DWord, flags : SizeT) : Bool
  fun delete_timer_queue_timer = DeleteTimerQueueTimer(queue_handle : Handle, timer_handle : Handle, completion_event : Handle) : Bool
  fun get_last_error = GetLastError : DWord
  fun set_last_error = SetLastError(code : DWord) : Void

  # StartupInfoA.deFlags
  STARTF_USESTDHANDLES = 0x00000100_u32

  # CreateProcessA.dwCreationFlags
  NORMAL_PRIORITY_CLASS = 0x00000020_u32
  CREATE_NO_WINDOW = 0x08000000_u32

  struct StartupInfoA
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
    lpReserved2: UInt8*
    hStdInput : Handle
    hStdOutput : Handle
    hStdError : Handle
  end

  struct Process_Information
    hProcess : Handle
    hThread : Handle
    dwProcessId : DWord
    dwThreadId : DWord
  end
  
  fun create_process = CreateProcessA(lpApplicationName : UInt8*, lpCommandLine : UInt8*, 
                                      lpProcessAttributes : SecurityAttributes*, lpThreadAttributes : SecurityAttributes*, bInheritHandles : BOOL,
                                      dwCreationFlags : DWord, lpEnvironment : Void*, lpCurrentDirectory : UInt8*, 
                                      lpStartupInfo : StartupInfoA*, lpProcessInformation : Process_Information*) : BOOL
  fun kill_process = KillProcess(hProcess : Handle, uExitCode : UInt32) : BOOL
  fun get_exit_code_process = GetExitCodeProcess(hProcess : Handle, lpExitCode : DWord*) : BOOL
  
  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32

  fun format_message = FormatMessageA(flags : DWord, source : Void*, msg : DWord, lang : DWord, buffer : UInt8*, size : DWord, args : Void*) : DWord

  WSASYSNOTREADY     = 10091
  WSAVERNOTSUPPORTED = 10092
  WSAEINPROGRESS     = 10036
  WSAEPROCLIM        = 10067
  WSAEFAULT          = 10014
  WSAEINVAL          = 10022

  struct WSAData
    version : UInt16
    high_version : UInt16
    description : UInt8[257]
    system_status : UInt8[129]
    max_sockets : UInt16
    max_udp_datagram : UInt16
    vendor_info : UInt8*
  end

  fun wsa_startup = WSAStartup(version : Int16, data : WSAData*) : Int32

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/ms724950(v=vs.85).aspx
  struct SystemTime
    year : Word
    month : Word
    day_of_week : Word
    day : Word
    hour : Word
    minute : Word
    second : Word
    milliseconds : Word
  end

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/ms725481(v=vs.85).aspx
  struct TimeZoneInformation
    bias : Long
    standard_name : StaticArray(WChar, 32)
    standard_date : SystemTime
    standard_bias : Long
    daylight_name : StaticArray(WChar, 32)
    daylight_date : SystemTime
    daylight_bias : Long
  end

  struct FileTime
    low_date_time : DWord
    high_date_time : DWord
  end

  fun get_time_zone_information = GetTimeZoneInformation(tz_info : TimeZoneInformation*) : DWord
  fun get_system_time_as_file_time = GetSystemTimeAsFileTime(time : FileTime*)


  fun get_computer_name = GetComputerNameA(buffer : UInt8*, size : DWord*) : BOOL

  fun cxx_throw_exception = _CxxThrowException(exception_object : Void*, throw_info : Void*) : NoReturn
end

module WindowsExt
  @[Primitive(:throw_info)]
  def self.throw_info : Void*
  end
end

require "winerror.cr"

data = uninitialized LibWindows::WSAData
if LibWindows.wsa_startup(0x0202, pointerof(data)) != 0
  raise WinError.new "WSAStartup"
end
