{% skip_file unless flag?(:win32) %}
require "c/handleapi"
require "crystal/system/thread_linked_list"

# :nodoc:
module Crystal::IOCP
  # :nodoc:
  class CompletionKey
    enum Tag
      ProcessRun
      StdinRead
    end

    property fiber : Fiber?
    getter tag : Tag

    def initialize(@tag : Tag, @fiber : Fiber? = nil)
    end
  end

  def self.wait_queued_completions(timeout, alertable = false, &)
    overlapped_entries = uninitialized LibC::OVERLAPPED_ENTRY[1]

    if timeout > UInt64::MAX
      timeout = LibC::INFINITE
    else
      timeout = timeout.to_u64
    end
    result = LibC.GetQueuedCompletionStatusEx(Crystal::EventLoop.current.iocp, overlapped_entries, overlapped_entries.size, out removed, timeout, alertable)
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

    removed.times do |i|
      entry = overlapped_entries[i]

      # at the moment only `::Process#wait` uses a non-nil completion key; all
      # I/O operations, including socket ones, do not set this field
      case completion_key = Pointer(Void).new(entry.lpCompletionKey).as(CompletionKey?)
      in Nil
        operation = OverlappedOperation.unbox(entry.lpOverlapped)
        operation.schedule { |fiber| yield fiber }
      in CompletionKey
        if completion_key_valid?(completion_key, entry.dwNumberOfBytesTransferred)
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

  private def self.completion_key_valid?(completion_key, number_of_bytes_transferred)
    case completion_key.tag
    in .process_run?
      number_of_bytes_transferred.in?(LibC::JOB_OBJECT_MSG_EXIT_PROCESS, LibC::JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS)
    in .stdin_read?
      true
    end
  end

  abstract class OverlappedOperation
    enum State
      STARTED
      DONE
    end

    abstract def wait_for_result(timeout, & : WinError ->)

    @overlapped = LibC::OVERLAPPED.new
    @fiber = Fiber.current
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
      @fiber.cancel_timeout
      @state = :done
    end

    private def wait_for_completion(timeout)
      if timeout
        sleep timeout
      else
        Fiber.suspend
      end

      unless @state.done?
        if try_cancel
          # Wait for cancellation to complete. We must not free the operation
          # until it's completed.
          Fiber.suspend
        end
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
