lib LibWindows
  STD_INPUT_HANDLE = 0xFFFFFFF6_u32
  STD_OUTPUT_HANDLE = 0xFFFFFFF5_u32
  STD_ERROR_HANDLE = 0xFFFFFFF4_u32

  FILE_TYPE_UNKNOWN = 0x0000
  FILE_TYPE_DISK = 0x0001
  FILE_TYPE_CHAR = 0x0002
  FILE_TYPE_PIPE = 0x0003
  FILE_TYPE_REMOTE = 0x8000

  alias DWord = UInt32
  alias Handle = Void*
  alias SizeT = UInt64 # FIXME

  INVALID_HANDLE_VALUE = Pointer(Void).new((-1).to_u64)
  INFINITY = 0xFFFFFFFF_u32

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
  fun get_current_process = GetCurrentProcess() : Handle

  @[CallConvention("X86_StdCall")]
  fun get_current_thread = GetCurrentThread() : Handle

  WAIT_ABANDONED = 0x00000080_u32
  WAIT_OBJECT_0  = 0x00000000_u32
  WAIT_TIMEOUT   = 0x00000102_u32
  WAIT_FAILED    = 0xFFFFFFFF_u32

  @[CallConvention("X86_StdCall")]
  fun wait_for_single_object = WaitForSingleObject(handle : Handle, timeout_millis : DWord) : DWord

  WSASYSNOTREADY = 10091
  WSAVERNOTSUPPORTED = 10092
  WSAEINPROGRESS = 10036
  WSAEPROCLIM = 10067
  WSAEFAULT = 10014
  WSAEINVAL = 10022

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
  fun wsa_startup = WSAStartup(version : Int16, data : WSAData*) : Int32;
end

data = uninitialized LibWindows::WSAData
if LibWindows.wsa_startup(0x0202, pointerof(data)) != 0
  raise "WSAStartup failed"
end
