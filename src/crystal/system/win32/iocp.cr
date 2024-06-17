{% skip_file unless flag?(:win32) %}
require "c/handleapi"
require "crystal/system/thread_linked_list"

# :nodoc:
module Crystal::IOCP
  # :nodoc:
  class CompletionKey
    property fiber : Fiber?
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
      when Nil
        operation = OverlappedOperation.unbox(entry.lpOverlapped)
        operation.schedule { |fiber| yield fiber }
      else
        case entry.dwNumberOfBytesTransferred
        when LibC::JOB_OBJECT_MSG_EXIT_PROCESS, LibC::JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS
          if fiber = completion_key.fiber
            # this ensures the `::Process` doesn't keep an indirect reference to
            # `::Thread.current`, as that leads to a finalization cycle
            completion_key.fiber = nil

            yield fiber
          else
            # the `Process` exits before a call to `#wait`; do nothing
          end
        end
      end
    end

    false
  end

  class OverlappedOperation
    enum State
      INITIALIZED
      STARTED
      DONE
      CANCELLED
    end

    @overlapped = LibC::OVERLAPPED.new
    @fiber = Fiber.current
    @state : State = :initialized
    property next : OverlappedOperation?
    property previous : OverlappedOperation?
    @@canceled = Thread::LinkedList(OverlappedOperation).new

    def self.run(handle, &)
      operation = OverlappedOperation.new
      begin
        yield operation
      ensure
        operation.done(handle)
      end
    end

    def self.unbox(overlapped : LibC::OVERLAPPED*)
      start = overlapped.as(Pointer(UInt8)) - offsetof(OverlappedOperation, @overlapped)
      Box(OverlappedOperation).unbox(start.as(Pointer(Void)))
    end

    def start
      raise Exception.new("Invalid state #{@state}") unless @state.initialized?
      @state = State::STARTED
      self
    end

    def to_unsafe
      pointerof(@overlapped)
    end

    def result(handle, &)
      raise Exception.new("Invalid state #{@state}") unless @state.done? || @state.started?
      result = LibC.GetOverlappedResult(handle, self, out bytes, 0)
      if result.zero?
        error = WinError.value
        yield error

        raise IO::Error.from_os_error("GetOverlappedResult", error)
      end

      bytes
    end

    def wsa_result(socket, &)
      raise Exception.new("Invalid state #{@state}") unless @state.done? || @state.started?
      flags = 0_u32
      result = LibC.WSAGetOverlappedResult(socket, self, out bytes, false, pointerof(flags))
      if result.zero?
        error = WinError.wsa_value
        yield error

        raise IO::Error.from_os_error("WSAGetOverlappedResult", error)
      end

      bytes
    end

    protected def schedule(&)
      case @state
      when .started?
        yield @fiber
        done!
      when .cancelled?
        @@canceled.delete(self)
      else
        raise Exception.new("Invalid state #{@state}")
      end
    end

    protected def done(handle)
      case @state
      when .started?
        handle = LibC::HANDLE.new(handle) if handle.is_a?(LibC::SOCKET)

        # https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelioex
        # > The application must not free or reuse the OVERLAPPED structure
        # associated with the canceled I/O operations until they have completed
        if LibC.CancelIoEx(handle, self) != 0
          @state = :cancelled
          @@canceled.push(self) # to increase lifetime
        end
      end
    end

    def done!
      @state = :done
    end
  end

  # Returns `false` if the operation timed out.
  def self.schedule_overlapped(timeout : Time::Span?, line = __LINE__) : Bool
    if timeout
      timeout_event = Crystal::IOCP::Event.new(Fiber.current)
      timeout_event.add(timeout)
    else
      timeout_event = Crystal::IOCP::Event.new(Fiber.current, Time::Span::MAX)
    end
    # memoize event loop to make sure that we still target the same instance
    # after wakeup (guaranteed by current MT model but let's be future proof)
    event_loop = Crystal::EventLoop.current
    event_loop.enqueue(timeout_event)

    Fiber.suspend

    event_loop.dequeue(timeout_event)
  end

  def self.overlapped_operation(target, handle, method, timeout, *, writing = false, &)
    OverlappedOperation.run(handle) do |operation|
      result, value = yield operation.start

      if result == 0
        case error = WinError.value
        when .error_handle_eof?
          return 0_u32
        when .error_broken_pipe?
          return 0_u32
        when .error_io_pending?
          # the operation is running asynchronously; do nothing
        when .error_access_denied?
          raise IO::Error.new "File not open for #{writing ? "writing" : "reading"}", target: target
        else
          raise IO::Error.from_os_error(method, error, target: target)
        end
      else
        operation.done!
        return value
      end

      schedule_overlapped(timeout)

      operation.result(handle) do |error|
        case error
        when .error_io_incomplete?
          raise IO::TimeoutError.new("#{method} timed out")
        when .error_handle_eof?
          return 0_u32
        when .error_broken_pipe?
          # TODO: this is needed for `Process.run`, can we do without it?
          return 0_u32
        end
      end
    end
  end

  def self.wsa_overlapped_operation(target, socket, method, timeout, connreset_is_error = true, &)
    OverlappedOperation.run(socket) do |operation|
      result, value = yield operation.start

      if result == LibC::SOCKET_ERROR
        case error = WinError.wsa_value
        when .wsa_io_pending?
          # the operation is running asynchronously; do nothing
        else
          raise IO::Error.from_os_error(method, error, target: target)
        end
      else
        operation.done!
        return value
      end

      schedule_overlapped(timeout)

      operation.wsa_result(socket) do |error|
        case error
        when .wsa_io_incomplete?
          raise IO::TimeoutError.new("#{method} timed out")
        when .wsaeconnreset?
          return 0_u32 unless connreset_is_error
        end
      end
    end
  end
end
