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

  def overlapped_write(socket, method, &)
    overlapped_operation(socket, method, write_timeout) do |operation|
      yield operation
    end
  end

  def overlapped_read(socket, method, &)
    overlapped_operation(socket, method, read_timeout) do |operation|
      yield operation
    end
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

    @overlapped = LibC::WSAOVERLAPPED.new
    @fiber : Fiber? = nil
    @state : State = :initialized
    property next : OverlappedOperation?
    property previous : OverlappedOperation?
    @@canceled = Thread::LinkedList(OverlappedOperation).new

    def self.run(socket, &)
      operation = OverlappedOperation.new
      begin
        yield operation
      ensure
        operation.done(socket)
      end
    end

    def self.schedule(overlapped : LibC::WSAOVERLAPPED*, &)
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

    def result(socket, &)
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

    protected def done(socket)
      case @state
      when .started?
        # Microsoft documentation:
        # The application must not free or reuse the OVERLAPPED structure associated with the canceled I/O operations until they have completed
        if LibC.CancelIoEx(LibC::HANDLE.new(socket), pointerof(@overlapped)) != 0
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

  def overlapped_operation(socket, method, timeout, connreset_is_error = true, &)
    OverlappedOperation.run(socket) do |operation|
      result = yield operation.start

      if result == LibC::SOCKET_ERROR
        error = WinError.wsa_value

        unless error.wsa_io_pending?
          raise IO::Error.from_os_error(method, error)
        end
      end

      schedule_overlapped(timeout)

      operation.result(socket) do |error|
        case error
        when .wsa_io_incomplete?
          raise TimeoutError.new("#{method} timed out")
        when .wsaeconnreset?
          return 0_u32 unless connreset_is_error
        end
      end
    end
  end

  def overlapped_connect(socket, method, &)
    OverlappedOperation.run(socket) do |operation|
      yield operation.start

      schedule_overlapped(read_timeout || 1.seconds)

      operation.result(socket) do |error|
        case error
        when .wsa_io_incomplete?, .wsaeconnrefused?
          return ::Socket::ConnectError.from_os_error(method, error)
        when .error_operation_aborted?
          # FIXME: Not sure why this is necessary
          return ::Socket::ConnectError.from_os_error(method, error)
        end
      end

      nil
    end
  end

  def overlapped_accept(socket, method, &)
    OverlappedOperation.run(socket) do |operation|
      yield operation.start

      unless schedule_overlapped(read_timeout)
        raise IO::TimeoutError.new("#{method} timed out")
      end

      operation.result(socket) do |error|
        case error
        when .wsa_io_incomplete?, .wsaenotsock?
          return false
        end
      end

      true
    end
  end
end
