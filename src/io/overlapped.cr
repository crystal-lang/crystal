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

  @[Extern]
  struct OverlappedOperation
    getter overlapped : LibC::WSAOVERLAPPED

    def initialize(@overlapped)
    end
  end

  def create_operation
    overlapped = LibC::WSAOVERLAPPED.new
    OverlappedOperation.new(overlapped)
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
    Crystal::EventLoop.wait_completion(timeout.try(&.total_milliseconds) || LibC::INFINITE)
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

    unless schedule_overlapped(read_timeout)
      return ::Socket::ConnectError.new(method)
    end

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
