{% skip_file unless flag?(:win32) %}
require "c/handleapi"
require "crystal/system/thread_linked_list"

module IO::Overlapped
  @read_timeout : Time::Span?
  @write_timeout : Time::Span?

  # Returns the time to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout : Time::Span?
    @read_timeout
  end

  # Sets the time to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout=(timeout : Time::Span?) : ::Time::Span?
    @read_timeout = timeout
  end

  # Sets the number of seconds to wait when reading before raising an `IO::TimeoutError`.
  def read_timeout=(read_timeout : Number) : Number
    self.read_timeout = read_timeout.seconds
    read_timeout
  end

  # Returns the time to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout : Time::Span?
    @write_timeout
  end

  # Sets the time to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout=(timeout : Time::Span?) : ::Time::Span?
    @write_timeout = timeout
  end

  # Sets the number of seconds to wait when writing before raising an `IO::TimeoutError`.
  def write_timeout=(write_timeout : Number) : Number
    self.write_timeout = write_timeout.seconds
    write_timeout
  end

  def self.wait_queued_completions(timeout, &)
    overlapped_entries = uninitialized LibC::OVERLAPPED_ENTRY[1]

    if timeout > UInt64::MAX
      timeout = LibC::INFINITE
    else
      timeout = timeout.to_u64
    end
    result = LibC.GetQueuedCompletionStatusEx(Crystal::Scheduler.event_loop.iocp, overlapped_entries, overlapped_entries.size, out removed, timeout, false)
    if result == 0
      error = WinError.value
      if timeout && error.wait_timeout?
        return true
      else
        raise IO::Error.from_os_error("GetQueuedCompletionStatusEx", error)
      end
    end

    if removed == 0
      raise IO::Error.new("GetQueuedCompletionStatusEx returned 0")
    end

    removed.times do |i|
      OverlappedOperation.schedule(overlapped_entries[i].lpOverlapped) { |fiber| yield fiber }
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
    @fiber : Fiber? = nil
    @state : State = :initialized
    property next : OverlappedOperation?
    property previous : OverlappedOperation?
    @@canceled = Thread::LinkedList(OverlappedOperation).new
    property? synchronous = false

    def self.run(handle, &)
      operation = OverlappedOperation.new
      begin
        yield operation
      ensure
        operation.done(handle)
      end
    end

    def self.schedule(overlapped : LibC::OVERLAPPED*, &)
      start = overlapped.as(Pointer(UInt8)) - offsetof(OverlappedOperation, @overlapped)
      operation = Box(OverlappedOperation).unbox(start.as(Pointer(Void)))
      operation.schedule { |fiber| yield fiber }
    end

    def start
      raise Exception.new("Invalid state #{@state}") unless @state.initialized?
      @fiber = Fiber.current
      @state = State::STARTED
      pointerof(@overlapped)
    end

    def result(handle, &)
      raise Exception.new("Invalid state #{@state}") unless @state.done? || @state.started?
      result = LibC.GetOverlappedResult(handle, pointerof(@overlapped), out bytes, 0)
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
      result = LibC.WSAGetOverlappedResult(socket, pointerof(@overlapped), out bytes, false, pointerof(flags))
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
        yield @fiber.not_nil!
        @state = :done
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

        # Microsoft documentation:
        # The application must not free or reuse the OVERLAPPED structure
        # associated with the canceled I/O operations until they have completed
        # (this does not apply to asynchronous operations that finished
        # synchronously, as nothing would be queued to the IOCP)
        if !synchronous? && LibC.CancelIoEx(handle, pointerof(@overlapped)) != 0
          @state = :cancelled
          @@canceled.push(self) # to increase lifetime
        end
      end
    end
  end

  # Returns `false` if the operation timed out.
  def schedule_overlapped(timeout : Time::Span?, line = __LINE__) : Bool
    if timeout
      timeout_event = Crystal::Iocp::Event.new(Fiber.current)
      timeout_event.add(timeout)
    else
      timeout_event = Crystal::Iocp::Event.new(Fiber.current, Time::Span::MAX)
    end
    Crystal::Scheduler.event_loop.enqueue(timeout_event)

    Crystal::Scheduler.reschedule

    Crystal::Scheduler.event_loop.dequeue(timeout_event)
  end

  def overlapped_operation(handle, method, timeout, *, writing = false, &)
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
          raise IO::Error.new "File not open for #{writing ? "writing" : "reading"}"
        else
          raise IO::Error.from_os_error(method, error)
        end
      else
        operation.synchronous = true
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

  def wsa_overlapped_operation(socket, method, timeout, connreset_is_error = true, &)
    OverlappedOperation.run(socket) do |operation|
      result, value = yield operation.start

      if result == LibC::SOCKET_ERROR
        case error = WinError.wsa_value
        when .wsa_io_pending?
          # the operation is running asynchronously; do nothing
        else
          raise IO::Error.from_os_error(method, error)
        end
      else
        operation.synchronous = true
        return value
      end

      schedule_overlapped(timeout)

      operation.wsa_result(socket) do |error|
        case error
        when .wsa_io_incomplete?
          raise TimeoutError.new("#{method} timed out")
        when .wsaeconnreset?
          return 0_u32 unless connreset_is_error
        end
      end
    end
  end
end
