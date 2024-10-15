require "c/ioapiset"
require "crystal/system/print_error"
require "./iocp"

# :nodoc:
class Crystal::IOCP::EventLoop < Crystal::EventLoop
  # This is a list of resume and timeout events managed outside of IOCP.
  @queue = Deque(Crystal::IOCP::Event).new

  @lock = Crystal::SpinLock.new
  @interrupted = Atomic(Bool).new(false)
  @blocked_thread = Atomic(Thread?).new(nil)

  # Returns the base IO Completion Port
  getter iocp : LibC::HANDLE do
    create_completion_port(LibC::INVALID_HANDLE_VALUE, nil)
  end

  def create_completion_port(handle : LibC::HANDLE, parent : LibC::HANDLE? = iocp)
    iocp = LibC.CreateIoCompletionPort(handle, parent, nil, 0)
    if iocp.null?
      raise IO::Error.from_winerror("CreateIoCompletionPort")
    end
    if parent
      # all overlapped operations may finish synchronously, in which case we do
      # not reschedule the running fiber; the following call tells Win32 not to
      # queue an I/O completion packet to the associated IOCP as well, as this
      # would be done by default
      if LibC.SetFileCompletionNotificationModes(handle, LibC::FILE_SKIP_COMPLETION_PORT_ON_SUCCESS) == 0
        raise IO::Error.from_winerror("SetFileCompletionNotificationModes")
      end
    end
    iocp
  end

  # Runs the event loop and enqueues the fiber for the next upcoming event or
  # completion.
  def run(blocking : Bool) : Bool
    # Pull the next upcoming event from the event queue. This determines the
    # timeout for waiting on the completion port.
    # OPTIMIZE: Implement @queue as a priority queue in order to avoid this
    # explicit search for the lowest value and dequeue more efficient.
    next_event = @queue.min_by?(&.wake_at)

    # no registered events: nothing to wait for
    return false unless next_event

    now = Time.monotonic

    if next_event.wake_at > now
      # There is no event ready to wake. We wait for completions until the next
      # event wake time, unless nonblocking or already interrupted (timeout
      # immediately).
      if blocking
        @lock.sync do
          if @interrupted.get(:acquire)
            blocking = false
          else
            # memorize the blocked thread (so we can alert it)
            @blocked_thread.set(Thread.current, :release)
          end
        end
      end

      wait_time = blocking ? (next_event.wake_at - now).total_milliseconds : 0
      timed_out = IOCP.wait_queued_completions(wait_time, alertable: blocking) do |fiber|
        # This block may run multiple times. Every single fiber gets enqueued.
        fiber.enqueue
      end

      @blocked_thread.set(nil, :release)
      @interrupted.set(false, :release)

      # The wait for completion enqueued events.
      return true unless timed_out

      # Wait for completion timed out but it may have been interrupted or we ask
      # for immediate timeout (nonblocking), so we check for the next event
      # readiness again:
      return false if next_event.wake_at > Time.monotonic
    end

    # next_event gets activated because its wake time is passed, either from the
    # start or because completion wait has timed out.

    dequeue next_event

    fiber = next_event.fiber

    # If the waiting fiber was already shut down in the mean time, we can just
    # abandon here. There's no need to go for the next event because the scheduler
    # will just try again.
    # OPTIMIZE: It might still be worth considering to start over from the top
    # or call recursively, in order to ensure at least one fiber get enqueued.
    # This would avoid the scheduler needing to looking at runnable again just
    # to notice it's still empty. The lock involved there should typically be
    # uncontested though, so it's probably not a big deal.
    return false if fiber.dead?

    # A timeout event needs special handling because it does not necessarily
    # means to resume the fiber directly, in case a different select branch
    # was already activated.
    if next_event.timeout? && (select_action = fiber.timeout_select_action)
      fiber.timeout_select_action = nil
      select_action.time_expired(fiber)
    else
      fiber.enqueue
    end

    # We enqueued a fiber.
    true
  end

  def interrupt : Nil
    thread = nil

    @lock.sync do
      @interrupted.set(true)
      thread = @blocked_thread.swap(nil, :acquire)
    end
    return unless thread

    # alert the thread to interrupt GetQueuedCompletionStatusEx
    LibC.QueueUserAPC(->(ptr : LibC::ULONG_PTR) { }, thread, LibC::ULONG_PTR.new(0))
  end

  def enqueue(event : Crystal::IOCP::Event)
    unless @queue.includes?(event)
      @queue << event
    end
  end

  def dequeue(event : Crystal::IOCP::Event)
    @queue.delete(event)
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::EventLoop::Event
    Crystal::IOCP::Event.new(fiber)
  end

  def create_timeout_event(fiber) : Crystal::EventLoop::Event
    Crystal::IOCP::Event.new(fiber, timeout: true)
  end

  def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    IOCP.overlapped_operation(file_descriptor, "ReadFile", file_descriptor.read_timeout) do |overlapped|
      ret = LibC.ReadFile(file_descriptor.windows_handle, slice, slice.size, out byte_count, overlapped)
      {ret, byte_count}
    end.to_i32
  end

  def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    IOCP.overlapped_operation(file_descriptor, "WriteFile", file_descriptor.write_timeout, writing: true) do |overlapped|
      ret = LibC.WriteFile(file_descriptor.windows_handle, slice, slice.size, out byte_count, overlapped)
      {ret, byte_count}
    end.to_i32
  end

  def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
    LibC.CancelIoEx(file_descriptor.windows_handle, nil) unless file_descriptor.system_blocking?
  end

  def remove(file_descriptor : Crystal::System::FileDescriptor) : Nil
  end

  private def wsa_buffer(bytes)
    wsabuf = LibC::WSABUF.new
    wsabuf.len = bytes.size
    wsabuf.buf = bytes.to_unsafe
    wsabuf
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    wsabuf = wsa_buffer(slice)

    bytes_read = IOCP.wsa_overlapped_operation(socket, socket.fd, "WSARecv", socket.read_timeout, connreset_is_error: false) do |overlapped|
      flags = 0_u32
      ret = LibC.WSARecv(socket.fd, pointerof(wsabuf), 1, out bytes_received, pointerof(flags), overlapped, nil)
      {ret, bytes_received}
    end

    bytes_read.to_i32
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    wsabuf = wsa_buffer(slice)

    bytes = IOCP.wsa_overlapped_operation(socket, socket.fd, "WSASend", socket.write_timeout) do |overlapped|
      ret = LibC.WSASend(socket.fd, pointerof(wsabuf), 1, out bytes_sent, 0, overlapped, nil)
      {ret, bytes_sent}
    end

    bytes.to_i32
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    wsabuf = wsa_buffer(slice)
    bytes_written = IOCP.wsa_overlapped_operation(socket, socket.fd, "WSASendTo", socket.write_timeout) do |overlapped|
      ret = LibC.WSASendTo(socket.fd, pointerof(wsabuf), 1, out bytes_sent, 0, address, address.size, overlapped, nil)
      {ret, bytes_sent}
    end
    raise ::Socket::Error.from_wsa_error("Error sending datagram to #{address}") if bytes_written == -1

    # to_i32 is fine because string/slice sizes are an Int32
    bytes_written.to_i32
  end

  def receive(socket : ::Socket, slice : Bytes) : Int32
    receive_from(socket, slice)[0]
  end

  def receive_from(socket : ::Socket, slice : Bytes) : Tuple(Int32, ::Socket::Address)
    sockaddr = Pointer(LibC::SOCKADDR_STORAGE).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = socket.family
    sockaddr.value = copy

    addrlen = sizeof(LibC::SOCKADDR_STORAGE)

    wsabuf = wsa_buffer(slice)

    flags = 0_u32
    bytes_read = IOCP.wsa_overlapped_operation(socket, socket.fd, "WSARecvFrom", socket.read_timeout) do |overlapped|
      ret = LibC.WSARecvFrom(socket.fd, pointerof(wsabuf), 1, out bytes_received, pointerof(flags), sockaddr, pointerof(addrlen), overlapped, nil)
      {ret, bytes_received}
    end

    {bytes_read.to_i32, ::Socket::Address.from(sockaddr, addrlen)}
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : ::Time::Span?) : IO::Error?
    socket.overlapped_connect(socket.fd, "ConnectEx", timeout) do |overlapped|
      # This is: LibC.ConnectEx(fd, address, address.size, nil, 0, nil, overlapped)
      Crystal::System::Socket.connect_ex.call(socket.fd, address.to_unsafe, address.size, Pointer(Void).null, 0_u32, Pointer(UInt32).null, overlapped.to_unsafe)
    end
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
    socket.system_accept do |client_handle|
      address_size = sizeof(LibC::SOCKADDR_STORAGE) + 16

      # buffer_size is set to zero to only accept the connection and don't receive any data.
      # That will be a different operation.
      #
      # > If dwReceiveDataLength is zero, accepting the connection will not result in a receive operation.
      # > Instead, AcceptEx completes as soon as a connection arrives, without waiting for any data.
      #
      # TODO: Investigate benefits from receiving data here directly. It's hard to integrate into the event loop and socket API.
      buffer_size = 0
      output_buffer = Bytes.new(address_size * 2 + buffer_size)

      success = socket.overlapped_accept(socket.fd, "AcceptEx") do |overlapped|
        # This is: LibC.AcceptEx(fd, client_handle, output_buffer, buffer_size, address_size, address_size, out received_bytes, overlapped)
        received_bytes = uninitialized UInt32
        Crystal::System::Socket.accept_ex.call(socket.fd, client_handle,
          output_buffer.to_unsafe.as(Void*), buffer_size.to_u32!,
          address_size.to_u32!, address_size.to_u32!, pointerof(received_bytes), overlapped.to_unsafe)
      end

      if success
        # AcceptEx does not automatically set the socket options on the accepted
        # socket to match those of the listening socket, we need to ask for that
        # explicitly with SO_UPDATE_ACCEPT_CONTEXT
        socket.system_setsockopt client_handle, LibC::SO_UPDATE_ACCEPT_CONTEXT, socket.fd

        true
      else
        false
      end
    end
  end

  def close(socket : ::Socket) : Nil
  end

  def remove(socket : ::Socket) : Nil
  end
end

class Crystal::IOCP::Event
  include Crystal::EventLoop::Event

  getter fiber
  getter wake_at
  getter? timeout

  def initialize(@fiber : Fiber, @wake_at = Time.monotonic, *, @timeout = false)
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.current.dequeue(self)
  end

  def delete
    free
  end

  def add(timeout : Time::Span) : Nil
    @wake_at = Time.monotonic + timeout
    Crystal::EventLoop.current.enqueue(self)
  end
end
