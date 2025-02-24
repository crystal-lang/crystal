{% skip_file unless flag?(:win32) %}
require "c/handleapi"
require "c/ioapiset"
require "c/ntdll"
require "crystal/system/thread_linked_list"

# :nodoc:
struct Crystal::System::IOCP
  @@wait_completion_packet_methods : Bool? = nil

  {% if flag?(:interpreted) %}
    # We can't load the symbols from interpreted code since it would create
    # interpreted Proc. We thus merely check for the existence of the symbols,
    # then let the interpreter load the symbols, which will create interpreter
    # Proc (not interpreted) that can be called.
    class_getter?(wait_completion_packet_methods : Bool) do
      detect_wait_completion_packet_methods
    end

    private def self.detect_wait_completion_packet_methods : Bool
      if handle = LibC.LoadLibraryExW(Crystal::System.to_wstr("ntdll.dll"), nil, 0)
        !LibC.GetProcAddress(handle, "NtCreateWaitCompletionPacket").null?
      else
        false
      end
    end
  {% else %}
    @@_NtCreateWaitCompletionPacket = uninitialized LibNTDLL::NtCreateWaitCompletionPacketProc
    @@_NtAssociateWaitCompletionPacket = uninitialized LibNTDLL::NtAssociateWaitCompletionPacketProc
    @@_NtCancelWaitCompletionPacket = uninitialized LibNTDLL::NtCancelWaitCompletionPacketProc

    class_getter?(wait_completion_packet_methods : Bool) do
      load_wait_completion_packet_methods
    end

    private def self.load_wait_completion_packet_methods : Bool
      handle = LibC.LoadLibraryExW(Crystal::System.to_wstr("ntdll.dll"), nil, 0)
      return false if handle.null?

      pointer = LibC.GetProcAddress(handle, "NtCreateWaitCompletionPacket")
      return false if pointer.null?
      @@_NtCreateWaitCompletionPacket = LibNTDLL::NtCreateWaitCompletionPacketProc.new(pointer, Pointer(Void).null)

      pointer = LibC.GetProcAddress(handle, "NtAssociateWaitCompletionPacket")
      @@_NtAssociateWaitCompletionPacket = LibNTDLL::NtAssociateWaitCompletionPacketProc.new(pointer, Pointer(Void).null)

      pointer = LibC.GetProcAddress(handle, "NtCancelWaitCompletionPacket")
      @@_NtCancelWaitCompletionPacket = LibNTDLL::NtCancelWaitCompletionPacketProc.new(pointer, Pointer(Void).null)

      true
    end
  {% end %}

  # :nodoc:
  class CompletionKey
    enum Tag
      ProcessRun
      StdinRead
      Interrupt
      Timer
    end

    property fiber : ::Fiber?
    getter tag : Tag

    def initialize(@tag : Tag, @fiber : ::Fiber? = nil)
    end

    def valid?(number_of_bytes_transferred)
      case tag
      in .process_run?
        number_of_bytes_transferred.in?(LibC::JOB_OBJECT_MSG_EXIT_PROCESS, LibC::JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS)
      in .stdin_read?, .interrupt?, .timer?
        true
      end
    end
  end

  getter handle : LibC::HANDLE

  def initialize
    @handle = LibC.CreateIoCompletionPort(LibC::INVALID_HANDLE_VALUE, nil, nil, 0)
    raise IO::Error.from_winerror("CreateIoCompletionPort") if @handle.null?
  end

  def wait_queued_completions(timeout, alertable = false, &)
    overlapped_entries = uninitialized LibC::OVERLAPPED_ENTRY[64]

    if timeout > UInt64::MAX
      timeout = LibC::INFINITE
    else
      timeout = timeout.to_u64
    end

    result = LibC.GetQueuedCompletionStatusEx(@handle, overlapped_entries, overlapped_entries.size, out removed, timeout, alertable)

    if result == 0
      error = WinError.value
      if timeout && error.wait_timeout?
        return true
      elsif alertable && error.value == LibC::WAIT_IO_COMPLETION
        return true
      else
        raise IO::Error.from_os_error("GetQueuedCompletionStatusEx", error)
      end
    end

    if removed == 0
      raise IO::Error.new("GetQueuedCompletionStatusEx returned 0")
    end

    # TODO: wouldn't the processing fit better in `EventLoop::IOCP#run`?
    removed.times do |i|
      entry = overlapped_entries[i]

      # See `CompletionKey` for the operations that use a non-nil completion
      # key. All IO operations (include File, Socket) do not set this field.
      case completion_key = Pointer(Void).new(entry.lpCompletionKey).as(CompletionKey?)
      in Nil
        operation = OverlappedOperation.unbox(entry.lpOverlapped)
        Crystal.trace :evloop, "operation", op: operation.class.name, fiber: operation.@fiber
        operation.schedule { |fiber| yield fiber }
      in CompletionKey
        Crystal.trace :evloop, "completion", tag: completion_key.tag.to_s, bytes: entry.dwNumberOfBytesTransferred, fiber: completion_key.fiber

        if completion_key.valid?(entry.dwNumberOfBytesTransferred)
          # if `Process` exits before a call to `#wait`, this fiber will be
          # reset already
          if fiber = completion_key.fiber
            # this ensures existing references to `completion_key` do not keep
            # an indirect reference to `::Thread.current`, as that leads to a
            # finalization cycle
            completion_key.fiber = nil
            yield fiber
          end
        end
      end
    end

    false
  end

  def post_queued_completion_status(completion_key : CompletionKey, number_of_bytes_transferred = 0)
    result = LibC.PostQueuedCompletionStatus(@handle, number_of_bytes_transferred, completion_key.as(Void*).address, nil)
    raise RuntimeError.from_winerror("PostQueuedCompletionStatus") if result == 0
  end

  def create_wait_completion_packet : LibC::HANDLE
    packet_handle = LibC::HANDLE.null
    object_attributes = Pointer(LibC::OBJECT_ATTRIBUTES).null
    status =
      {% if flag?(:interpreted) %}
        LibNTDLL.NtCreateWaitCompletionPacket(pointerof(packet_handle), LibNTDLL::GENERIC_ALL, object_attributes)
      {% else %}
        @@_NtCreateWaitCompletionPacket.call(pointerof(packet_handle), LibNTDLL::GENERIC_ALL, object_attributes)
      {% end %}
    raise RuntimeError.from_os_error("NtCreateWaitCompletionPacket", WinError.from_ntstatus(status)) unless status == 0
    packet_handle
  end

  def associate_wait_completion_packet(wait_handle : LibC::HANDLE, target_handle : LibC::HANDLE, completion_key : CompletionKey) : Bool
    signaled = 0_u8
    status =
      {% if flag?(:interpreted) %}
        LibNTDLL.NtAssociateWaitCompletionPacket(wait_handle, @handle,
          target_handle, completion_key.as(Void*), nil, 0, nil, pointerof(signaled))
      {% else %}
        @@_NtAssociateWaitCompletionPacket.call(wait_handle, @handle,
          target_handle, completion_key.as(Void*), Pointer(Void).null,
          LibNTDLL::NTSTATUS.new!(0), Pointer(LibC::ULONG).null,
          pointerof(signaled))
      {% end %}
    raise RuntimeError.from_os_error("NtAssociateWaitCompletionPacket", WinError.from_ntstatus(status)) unless status == 0
    signaled == 1
  end

  def cancel_wait_completion_packet(wait_handle : LibC::HANDLE, remove_signaled : Bool) : LibNTDLL::NTSTATUS
    status =
      {% if flag?(:interpreted) %}
        LibNTDLL.NtCancelWaitCompletionPacket(wait_handle, remove_signaled ? 1 : 0)
      {% else %}
        @@_NtCancelWaitCompletionPacket.call(wait_handle, remove_signaled ? 1_u8 : 0_u8)
      {% end %}
    case status
    when LibC::STATUS_CANCELLED, LibC::STATUS_SUCCESS, LibC::STATUS_PENDING
      status
    else
      raise RuntimeError.from_os_error("NtCancelWaitCompletionPacket", WinError.from_ntstatus(status))
    end
  end

  abstract class OverlappedOperation
    enum State
      STARTED
      DONE
    end

    abstract def wait_for_result(timeout, & : WinError ->)
    private abstract def try_cancel : Bool

    @overlapped = LibC::OVERLAPPED.new
    @fiber = ::Fiber.current
    @state : State = :started

    def self.run(*args, **opts, &)
      operation_storage = uninitialized ReferenceStorage(self)
      operation = unsafe_construct(pointerof(operation_storage), *args, **opts)
      yield operation
    end

    def self.unbox(overlapped : LibC::OVERLAPPED*) : self
      start = overlapped.as(Pointer(UInt8)) - offsetof(self, @overlapped)
      Box(self).unbox(start.as(Pointer(Void)))
    end

    def to_unsafe
      pointerof(@overlapped)
    end

    protected def schedule(&)
      done!
      yield @fiber
    end

    private def done!
      @state = :done
    end

    private def wait_for_completion(timeout)
      if timeout
        event = ::Fiber.current.resume_event
        event.add(timeout)

        ::Fiber.suspend

        if event.timed_out?
          # By the time the fiber was resumed, the operation may have completed
          # concurrently.
          return if @state.done?
          return unless try_cancel

          # We cancelled the operation or failed to cancel it (e.g. race
          # condition), we must suspend the fiber again until the completion
          # port is notified of the actual result.
          ::Fiber.suspend
        end
      else
        ::Fiber.suspend
      end
    end
  end

  class IOOverlappedOperation < OverlappedOperation
    def initialize(@handle : LibC::HANDLE)
    end

    def wait_for_result(timeout, & : WinError ->)
      wait_for_completion(timeout)

      result = LibC.GetOverlappedResult(@handle, self, out bytes, 0)
      if result.zero?
        error = WinError.value
        yield error

        raise IO::Error.from_os_error("GetOverlappedResult", error)
      end

      bytes
    end

    private def try_cancel : Bool
      # Microsoft documentation:
      # The application must not free or reuse the OVERLAPPED structure
      # associated with the canceled I/O operations until they have completed
      # (this does not apply to asynchronous operations that finished
      # synchronously, as nothing would be queued to the IOCP)
      ret = LibC.CancelIoEx(@handle, self)
      if ret.zero?
        case error = WinError.value
        when .error_not_found?
          # Operation has already completed, do nothing
          return false
        else
          raise RuntimeError.from_os_error("CancelIoEx", os_error: error)
        end
      end
      true
    end
  end

  class WSAOverlappedOperation < OverlappedOperation
    def initialize(@handle : LibC::SOCKET)
    end

    def wait_for_result(timeout, & : WinError ->)
      wait_for_completion(timeout)

      flags = 0_u32
      result = LibC.WSAGetOverlappedResult(@handle, self, out bytes, false, pointerof(flags))
      if result.zero?
        error = WinError.wsa_value
        yield error

        raise IO::Error.from_os_error("WSAGetOverlappedResult", error)
      end

      bytes
    end

    private def try_cancel : Bool
      # Microsoft documentation:
      # The application must not free or reuse the OVERLAPPED structure
      # associated with the canceled I/O operations until they have completed
      # (this does not apply to asynchronous operations that finished
      # synchronously, as nothing would be queued to the IOCP)
      ret = LibC.CancelIoEx(Pointer(Void).new(@handle), self)
      if ret.zero?
        case error = WinError.value
        when .error_not_found?
          # Operation has already completed, do nothing
          return false
        else
          raise RuntimeError.from_os_error("CancelIoEx", os_error: error)
        end
      end
      true
    end
  end

  class GetAddrInfoOverlappedOperation < OverlappedOperation
    getter iocp
    setter cancel_handle : LibC::HANDLE = LibC::INVALID_HANDLE_VALUE

    def initialize(@iocp : LibC::HANDLE)
    end

    def wait_for_result(timeout, & : WinError ->)
      wait_for_completion(timeout)

      result = LibC.GetAddrInfoExOverlappedResult(self)
      unless result.zero?
        error = WinError.new(result.to_u32!)
        yield error

        raise ::Socket::Addrinfo::Error.from_os_error("GetAddrInfoExOverlappedResult", error)
      end

      @overlapped.union.pointer.as(LibC::ADDRINFOEXW**).value
    end

    private def try_cancel : Bool
      ret = LibC.GetAddrInfoExCancel(pointerof(@cancel_handle))
      unless ret.zero?
        case error = WinError.new(ret.to_u32!)
        when .wsa_invalid_handle?
          # Operation has already completed, do nothing
          return false
        else
          raise ::Socket::Addrinfo::Error.from_os_error("GetAddrInfoExCancel", error)
        end
      end
      true
    end
  end

  def self.overlapped_operation(file_descriptor, method, timeout, *, offset = nil, writing = false, &)
    handle = file_descriptor.windows_handle
    seekable = LibC.SetFilePointerEx(handle, 0, out original_offset, IO::Seek::Current) != 0

    IOOverlappedOperation.run(handle) do |operation|
      overlapped = operation.to_unsafe
      if seekable
        start_offset = offset || original_offset
        overlapped.value.union.offset.offset = LibC::DWORD.new!(start_offset)
        overlapped.value.union.offset.offsetHigh = LibC::DWORD.new!(start_offset >> 32)
      end
      result, value = yield operation

      if result == 0
        case error = WinError.value
        when .error_handle_eof?
          return 0_u32
        when .error_broken_pipe?
          return 0_u32
        when .error_io_pending?
          # the operation is running asynchronously; do nothing
        when .error_access_denied?
          raise IO::Error.new "File not open for #{writing ? "writing" : "reading"}", target: file_descriptor
        else
          raise IO::Error.from_os_error(method, error, target: file_descriptor)
        end
      else
        # operation completed synchronously; seek forward by number of bytes
        # read or written if handle is seekable, since overlapped I/O doesn't do
        # it automatically
        LibC.SetFilePointerEx(handle, value, nil, IO::Seek::Current) if seekable
        return value
      end

      byte_count = operation.wait_for_result(timeout) do |error|
        case error
        when .error_io_incomplete?, .error_operation_aborted?
          raise IO::TimeoutError.new("#{method} timed out")
        when .error_handle_eof?
          return 0_u32
        when .error_broken_pipe?
          # TODO: this is needed for `Process.run`, can we do without it?
          return 0_u32
        end
      end

      # operation completed asynchronously; seek to the original file position
      # plus the number of bytes read or written (other operations might have
      # moved the file pointer so we don't use `IO::Seek::Current` here), unless
      # we are calling `Crystal::System::FileDescriptor.pread`
      if seekable && !offset
        LibC.SetFilePointerEx(handle, original_offset + byte_count, nil, IO::Seek::Set)
      end
      byte_count
    end
  end

  def self.wsa_overlapped_operation(target, socket, method, timeout, connreset_is_error = true, &)
    WSAOverlappedOperation.run(socket) do |operation|
      result, value = yield operation

      if result == LibC::SOCKET_ERROR
        case error = WinError.wsa_value
        when .wsa_io_pending?
          # the operation is running asynchronously; do nothing
        else
          raise IO::Error.from_os_error(method, error, target: target)
        end
      else
        return value
      end

      operation.wait_for_result(timeout) do |error|
        case error
        when .wsa_io_incomplete?, .error_operation_aborted?
          raise IO::TimeoutError.new("#{method} timed out")
        when .wsaeconnreset?
          return 0_u32 unless connreset_is_error
        end
      end
    end
  end
end
