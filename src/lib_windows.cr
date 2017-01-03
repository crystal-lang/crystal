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

  alias DWord = UInt32
  alias Handle = Void*
  alias SizeT = UInt64 # FIXME

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
    inherit_handle : Bool
  end

  fun get_std_handle = GetStdHandle(std_handle : DWord) : Handle
  fun get_file_type = GetFileType(file : Handle) : DWord
  fun create_file = CreateFileA(filename : UInt8*, access : DWord, sharemode : DWord, security_attributes : SecurityAttributes*, creation : DWord, flags : DWord, template : Handle) : Handle
  fun read_file = ReadFile(file : Handle, buffer : UInt8*, size : DWord, read : DWord*, overlapped : Overlapped*) : Bool
  fun write_file = WriteFile(file : Handle, buffer : UInt8*, size : DWord, written : DWord*, overlapped : Overlapped*) : Bool
  fun close_handle = CloseHandle(file : Handle) : Bool

  fun create_io_completion_port = CreateIoCompletionPort(file : Handle, port : Handle, data : Void*, threads : DWord) : Handle
  fun get_queued_completion_status = GetQueuedCompletionStatus(port : Handle, bytes_transfered : DWord*, data : Void**, entry : Overlapped**, timeout_millis : DWord) : Bool
  fun post_queued_completion_status = PostQueuedCompletionStatus(port : Handle, bytes_transfered : DWord, data : Void*, entry : Overlapped*) : Bool
  fun get_current_process = GetCurrentProcess : Handle
  fun get_current_thread = GetCurrentThread : Handle

  WAIT_ABANDONED = 0x00000080_u32
  WAIT_OBJECT_0  = 0x00000000_u32
  WAIT_TIMEOUT   = 0x00000102_u32
  WAIT_FAILED    = 0xFFFFFFFF_u32

  fun wait_for_single_object = WaitForSingleObject(handle : Handle, timeout_millis : DWord) : DWord
  fun create_timer_queue_timer = CreateTimerQueueTimer(timer_handle : Handle*, queue_handle : Handle, callback : (Void*, Bool) ->, data : Void*, due : DWord, period : DWord, flags : SizeT) : Bool
  fun delete_timer_queue_timer = DeleteTimerQueueTimer(queue_handle : Handle, timer_handle : Handle, completion_event : Handle) : Bool
  fun get_last_error = GetLastError : DWord

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
end

require "winerror.cr"

data = uninitialized LibWindows::WSAData
if LibWindows.wsa_startup(0x0202, pointerof(data)) != 0
  raise WinError.new "WSAStartup"
end
