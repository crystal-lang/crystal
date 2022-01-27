{% skip_file unless flag?(:win32) %}
require "c/handleapi"

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

  def overlapped_write(socket, method)
    overlapped_operation(socket, method, write_timeout) do |operation|
      yield operation
    end
  end

  def overlapped_read(socket, method)
    overlapped_operation(socket, method, read_timeout) do |operation|
      yield operation
    end
  end

  def self.wait_queued_completions(timeout)
    overlapped_entries = uninitialized LibC::OVERLAPPED_ENTRY[1]

    if timeout > UInt64::MAX
      timeout = LibC::INFINITE
    else
      timeout = timeout.to_u64
    end
    result = LibC.GetQueuedCompletionStatusEx(Crystal::EventLoop.iocp, overlapped_entries, overlapped_entries.size, out removed, timeout, false)
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
      overlapped_entry = overlapped_entries[i]
      operation = overlapped_entry.lpOverlapped.as(OverlappedOperation*).value

      yield operation.fiber
    end

    false
  end

  @[Extern]
  struct OverlappedOperation
    @overlapped : LibC::WSAOVERLAPPED
    @fiber : Void*

    def initialize(@overlapped : LibC::WSAOVERLAPPED, fiber : Fiber)
      @fiber = Box.box(fiber)
    end

    def fiber
      raise "Invalid fiber:\n#{@overlapped} #{@overlapped.internal.to_s(16)}" if @fiber.null?
      Box(Fiber).unbox(@fiber)
    end
  end

  def create_operation
    overlapped = LibC::WSAOVERLAPPED.new
    OverlappedOperation.new(overlapped, Fiber.current)
  end

  def get_overlapped_result(socket, operation)
    flags = 0_u32
    result = LibC.WSAGetOverlappedResult(socket, pointerof(operation).as(LibC::OVERLAPPED*), out bytes, false, pointerof(flags))
    if result.zero?
      error = WinError.wsa_value
      yield error

      raise IO::Error.from_os_error("WSAGetOverlappedResult", error)
    end

    bytes
  end

  # Returns false the the operation timed out
  def schedule_overlapped(timeout : Time::Span?, line = __LINE__) : Bool
    if timeout
      timeout_event = Crystal::Event.new(Fiber.current)
      timeout_event.add(timeout)
    else
      timeout_event = Crystal::Event.new(Fiber.current, Time::Span::MAX)
    end
    Crystal::EventLoop.enqueue(timeout_event)

    Crystal::Scheduler.reschedule

    Crystal::EventLoop.dequeue(timeout_event)
  end

  def overlapped_operation(socket, method, timeout, connreset_is_error = true)
    operation = create_operation

    result = yield pointerof(operation).as(LibC::OVERLAPPED*)

    if result == LibC::SOCKET_ERROR
      error = WinError.wsa_value

      unless error.wsa_io_pending?
        raise IO::Error.from_os_error(method, error)
      end
    end

    schedule_overlapped(timeout)

    get_overlapped_result(socket, operation) do |error|
      case error
      when .wsa_io_incomplete?
        raise TimeoutError.new("#{method} timed out")
      when .wsaeconnreset?
        return 0_u32 unless connreset_is_error
      end
    end
  end

  def overlapped_connect(socket, method)
    operation = create_operation

    yield pointerof(operation).as(LibC::OVERLAPPED*)

    schedule_overlapped(read_timeout || 1.seconds)

    get_overlapped_result(socket, operation) do |error|
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

  def overlapped_accept(socket, method)
    operation = create_operation

    yield pointerof(operation).as(LibC::OVERLAPPED*)

    unless schedule_overlapped(read_timeout)
      raise IO::TimeoutError.new("accept timed out")
    end

    get_overlapped_result(socket, operation) do |error|
      case error
      when .wsa_io_incomplete?, .wsaenotsock?
        return false
      end
    end

    true
  end
end
