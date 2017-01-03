lib LibWindows
  STD_INPUT_HANDLE  = 0xFFFFFFF6_u32
  STD_OUTPUT_HANDLE = 0xFFFFFFF5_u32
  STD_ERROR_HANDLE  = 0xFFFFFFF4_u32

  FILE_TYPE_UNKNOWN = 0x0000
  FILE_TYPE_DISK    = 0x0001
  FILE_TYPE_CHAR    = 0x0002
  FILE_TYPE_PIPE    = 0x0003
  FILE_TYPE_REMOTE  = 0x8000

  # source https://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx
  alias Long = Int32
  alias Word = UInt16
  alias WChar = UInt16
  alias DWord = UInt32
  alias Handle = Void*
  alias SizeT = UInt64 # FIXME

  INVALID_HANDLE_VALUE = Pointer(Void).new((-1).to_u64)
  INFINITY             = 0xFFFFFFFF_u32

  @[CallConvention("X86_StdCall")]
  fun duplicate_handle = DuplicateHandle(source_process : Handle, source : Handle, target_process : Handle, target : Handle*, desired_access : DWord, inherit_handle : Bool, options : DWord) : Bool

  struct Overlapped
    internal : SizeT*
    internal_high : SizeT*
    pointer : Void*
    event : Handle
  end

  @[CallConvention("X86_StdCall")]
  fun get_std_handle = GetStdHandle(std_handle : DWord) : Handle

  @[CallConvention("X86_StdCall")]
  fun get_file_type = GetFileType(file : Handle) : DWord

  @[CallConvention("X86_StdCall")]
  fun write_file = WriteFile(file : Handle, buffer : UInt8*, size : DWord, written : DWord*, overlapped : Overlapped*) : Bool

  @[CallConvention("X86_StdCall")]
  fun close_handle = CloseHandle(file : Handle) : Bool

  @[CallConvention("X86_StdCall")]
  fun create_io_completion_port = CreateIoCompletionPort(file : Handle, port : Handle, data : Void*, threads : DWord) : Handle

  @[CallConvention("X86_StdCall")]
  fun get_queued_completion_status = GetQueuedCompletionStatus(port : Handle, bytes_transfered : DWord*, data : Void**, entry : Overlapped**, timeout_millis : DWord) : Bool

  @[CallConvention("X86_StdCall")]
  fun post_queued_completion_status = PostQueuedCompletionStatus(port : Handle, bytes_transfered : DWord, data : Void*, entry : Overlapped*) : Bool

  struct SecurityAttributes
    length : DWord
    security_descriptors : Void*
    inherit_handle : Bool
  end

  @[CallConvention("X86_StdCall")]
  fun get_current_process = GetCurrentProcess : Handle

  @[CallConvention("X86_StdCall")]
  fun get_current_thread = GetCurrentThread : Handle

  WAIT_ABANDONED = 0x00000080_u32
  WAIT_OBJECT_0  = 0x00000000_u32
  WAIT_TIMEOUT   = 0x00000102_u32
  WAIT_FAILED    = 0xFFFFFFFF_u32

  @[CallConvention("X86_StdCall")]
  fun wait_for_single_object = WaitForSingleObject(handle : Handle, timeout_millis : DWord) : DWord

  @[CallConvention("X86_StdCall")]
  fun create_timer_queue_timer = CreateTimerQueueTimer(timer_handle : Handle*, queue_handle : Handle, callback : (Void*, Bool) ->, data : Void*, due : DWord, period : DWord, flags : SizeT) : Bool

  @[CallConvention("X86_StdCall")]
  fun delete_timer_queue_timer = DeleteTimerQueueTimer(queue_handle : Handle, timer_handle : Handle, completion_event : Handle) : Bool

  @[CallConvention("X86_StdCall")]
  fun get_last_error = GetLastError : DWord

  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100_u32
  FORMAT_MESSAGE_IGNORE_INSERTS  = 0x00000200_u32
  FORMAT_MESSAGE_FROM_STRING     = 0x00000400_u32
  FORMAT_MESSAGE_FROM_HMODULE    = 0x00000800_u32
  FORMAT_MESSAGE_FROM_SYSTEM     = 0x00001000_u32
  FORMAT_MESSAGE_ARGUMENT_ARRAY  = 0x00002000_u32

  @[CallConvention("X86_StdCall")]
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

  @[CallConvention("X86_StdCall")]
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

  @[CallConvention("X86_StdCall")]
  fun get_time_zone_information = GetTimeZoneInformation(tz_info : TimeZoneInformation*) : DWord

  @[CallConvention("X86_StdCall")]
  fun get_system_time_as_file_time = GetSystemTimeAsFileTime(time : FileTime*)
end

require "winerror.cr"

data = uninitialized LibWindows::WSAData
if LibWindows.wsa_startup(0x0202, pointerof(data)) != 0
  raise WinError.new "WSAStartup"
end
