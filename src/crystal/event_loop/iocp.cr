# forward declaration for the require below to not create a module
class Crystal::EventLoop::IOCP < Crystal::EventLoop
end

require "c/ntdll"
require "../system/win32/iocp"
require "../system/win32/waitable_timer"
require "./timers"
require "./lock"
require "./iocp/*"

# :nodoc:
class Crystal::EventLoop::IOCP < Crystal::EventLoop
  def self.default_file_blocking?
    # here, blocking refers to setting FILE_FLAG_OVERLAPPED (non blocking) or
    # not (blocking)
    false
  end

  def self.default_socket_blocking?
    # here, blocking refers to the (non)blocking mode of winsocks, it is
    # independent from the WSA_FLAG_OVERLAPPED that we always set
    true
  end

  @waitable_timer : System::WaitableTimer?
  @timer_packet = LibC::HANDLE.null
  @timer_key : System::IOCP::CompletionKey?

  def initialize(parallelism : Int32)
    @timers_mutex = Thread::Mutex.new
    @timers = Timers(Timer).new

    # the completion port
    @iocp = System::IOCP.new

    # custom completion to interrupt a blocking run
    @interrupted = Atomic(Bool).new(false)
    @interrupt_key = System::IOCP::CompletionKey.new(:interrupt)

    # On Windows 10+ we leverage a high resolution timer with completion packet
    # to notify a completion port; on legacy Windows we fallback to the low
    # resolution timeout (~15.6ms)
    if System::IOCP.wait_completion_packet_methods?
      @waitable_timer = System::WaitableTimer.new
      @timer_packet = @iocp.create_wait_completion_packet
      @timer_key = System::IOCP::CompletionKey.new(:timer)
    end
  end

  # Returns the base IO Completion Port.
  def iocp_handle : LibC::HANDLE
    @iocp.handle
  end

  def create_completion_port(handle : LibC::HANDLE) : LibC::HANDLE
    iocp = LibC.CreateIoCompletionPort(handle, @iocp.handle, nil, 0)
    raise IO::Error.from_winerror("CreateIoCompletionPort") if iocp.null?

    # all overlapped operations may finish synchronously, in which case we do
    # not reschedule the running fiber; the following call tells Win32 not to
    # queue an I/O completion packet to the associated IOCP as well, as this
    # would be done by default
    if LibC.SetFileCompletionNotificationModes(handle, LibC::FILE_SKIP_COMPLETION_PORT_ON_SUCCESS) == 0
      raise IO::Error.from_winerror("SetFileCompletionNotificationModes")
    end

    iocp
  end

  # thread unsafe
  def run(blocking : Bool) : Bool
    enqueued = false

    run_impl(blocking) do |fiber|
      fiber.enqueue
      enqueued = true
    end

    enqueued
  end

  {% if flag?(:execution_context) %}
    # thread unsafe
    def run(queue : Fiber::List*, blocking : Bool) : Nil
      run_impl(blocking) { |fiber| queue.value.push(fiber) }
    end

    # the evloop has a single IOCP instance for the context and only one
    # scheduler must wait on the evloop at any time
    include EventLoop::Lock
  {% end %}

  # Runs the event loop and enqueues the fiber for the next upcoming event or
  # completion.
  private def run_impl(blocking : Bool, &) : Nil
    Crystal.trace :evloop, "run", blocking: blocking ? 1 : 0

    if @waitable_timer
      timeout = blocking ? LibC::INFINITE : 0_i64
    elsif blocking
      if time = @timers_mutex.synchronize { @timers.next_ready? }
        # convert absolute time of next timer to relative time, expressed in
        # milliseconds, rounded up
        # Cannot use `time.elapsed` here because it calls `::Time.instant` which
        # could be mocked.
        relative = Crystal::System::Time.instant.duration_since(time)
        timeout = (relative.to_i * 1000 + (relative.nanoseconds + 999_999) // 1_000_000)
      else
        timeout = LibC::INFINITE
      end
    else
      timeout = 0_i64
    end

    # the array must be at least as large as `overlapped_entries` in
    # `System::IOCP#wait_queued_completions`
    events = uninitialized FiberEvent[64]
    size = 0

    @iocp.wait_queued_completions(timeout) do |fiber|
      if (event = fiber.@resume_event) && event.wake_at?
        events[size] = event
        size += 1
      end
      yield fiber
    end

    @timers_mutex.synchronize do
      # cancel the timeout of completed operations
      events.to_slice[0...size].each do |event|
        @timers.delete(pointerof(event.@timer))
        event.clear
      end

      # run expired timers
      @timers.dequeue_ready do |timer|
        process_timer(timer) { |fiber| yield fiber }
      end

      # update timer
      rearm_waitable_timer(@timers.next_ready?, interruptible: false)
    end

    @interrupted.set(false, :release)
  end

  private def process_timer(timer : Pointer(Timer), &)
    fiber = timer.value.fiber

    case timer.value.type
    in .sleep?, .timeout?
      timer.value.timed_out!
    in .select_timeout?
      return unless select_action = fiber.timeout_select_action
      fiber.timeout_select_action = nil
      return unless select_action.time_expired?
      fiber.@timeout_event.as(FiberEvent).clear
    end

    yield fiber
  end

  def interrupt : Nil
    unless @interrupted.get(:acquire)
      @iocp.post_queued_completion_status(@interrupt_key)
    end
  end

  protected def add_timer(timer : Pointer(Timer)) : Nil
    @timers_mutex.synchronize do
      is_next_ready = @timers.add(timer)
      rearm_waitable_timer(timer.value.wake_at, interruptible: true) if is_next_ready
    end
  end

  protected def delete_timer(timer : Pointer(Timer)) : Nil
    @timers_mutex.synchronize do
      _, was_next_ready = @timers.delete(timer)
      rearm_waitable_timer(@timers.next_ready?, interruptible: false) if was_next_ready
    end
  end

  protected def rearm_waitable_timer(time : Time::Instant?, interruptible : Bool) : Nil
    if waitable_timer = @waitable_timer
      raise "BUG: @timer_packet was not initialized!" unless @timer_packet
      status = @iocp.cancel_wait_completion_packet(@timer_packet, true)
      if time
        waitable_timer.set(time)
        if status == LibC::STATUS_PENDING
          interrupt
        else
          # STATUS_CANCELLED, STATUS_SUCCESS
          @iocp.associate_wait_completion_packet(@timer_packet, waitable_timer.handle, @timer_key.not_nil!)
        end
      else
        waitable_timer.cancel
      end
    elsif interruptible
      interrupt
    end
  end

  def sleep(duration : Time::Span) : Nil
    timer = Timer.new(:sleep, Fiber.current, duration)
    add_timer(pointerof(timer))
    Fiber.suspend

    # safety check
    return if timer.timed_out?

    # try to avoid a double resume if possible, but another thread might be
    # running the evloop and dequeue the event in parallel, so a "can't resume
    # dead fiber" can still happen in a MT execution context.
    delete_timer(pointerof(timer))
    raise "BUG: #{timer.fiber} called sleep but was manually resumed before the timer expired!"
  end

  # Suspend the current fiber for *duration* and returns true if the timer
  # expired and false if the fiber was resumed early.
  #
  # Specific to IOCP to handle IO timeouts.
  def timeout(duration : Time::Span) : Bool
    event = Fiber.current.resume_event
    event.add(duration)

    Fiber.suspend

    if event.timed_out?
      true
    else
      event.delete
      false
    end
  end

  def create_resume_event(fiber : Fiber) : EventLoop::Event
    FiberEvent.new(:timeout, fiber)
  end

  def create_timeout_event(fiber : Fiber) : EventLoop::Event
    FiberEvent.new(:select_timeout, fiber)
  end

  def pipe(read_blocking : Bool?, write_blocking : Bool?) : {IO::FileDescriptor, IO::FileDescriptor}
    r, w = System::FileDescriptor.system_pipe(!!read_blocking, !!write_blocking)
    create_completion_port(LibC::HANDLE.new(r)) unless read_blocking
    create_completion_port(LibC::HANDLE.new(w)) unless write_blocking
    {
      IO::FileDescriptor.new(handle: r, blocking: !!read_blocking),
      IO::FileDescriptor.new(handle: w, blocking: !!write_blocking),
    }
  end

  def open(path : String, flags : Int32, permissions : File::Permissions, blocking : Bool?) : {System::FileDescriptor::Handle, Bool} | WinError
    access, disposition, attributes = System::File.posix_to_open_opts(flags, permissions, !!blocking)

    handle = LibC.CreateFileW(
      System.to_wstr(path),
      access,
      LibC::DEFAULT_SHARE_MODE, # UNIX semantics
      nil,
      disposition,
      attributes,
      LibC::HANDLE.null
    )

    if handle == LibC::INVALID_HANDLE_VALUE
      WinError.value
    else
      create_completion_port(handle) unless blocking
      {handle.address, !!blocking}
    end
  end

  def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    System::IOCP.overlapped_operation(file_descriptor, "ReadFile", file_descriptor.read_timeout) do |overlapped|
      ret = LibC.ReadFile(file_descriptor.windows_handle, slice, slice.size, out byte_count, overlapped)
      {ret, byte_count}
    end.to_i32
  end

  def wait_readable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    raise NotImplementedError.new("Crystal::System::IOCP#wait_readable(FileDescriptor)")
  end

  def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32
    bytes_written = System::IOCP.overlapped_operation(file_descriptor, "WriteFile", file_descriptor.write_timeout, writing: true) do |overlapped|
      overlapped.offset = UInt64::MAX if file_descriptor.system_append?

      ret = LibC.WriteFile(file_descriptor.windows_handle, slice, slice.size, out byte_count, overlapped)
      {ret, byte_count}
    end.to_i32

    # The overlapped offset forced a write to the end of the file, but unlike
    # synchronous writes, an asynchronous write incorrectly updates the file
    # pointer: it merely adds the number of written bytes to the current
    # position, disregarding that the offset might have changed it.
    #
    # We could seek before the async write (it works), but a concurrent fiber or
    # parallel thread could also seek and we'd end up overwriting instead of
    # appending; we need both the offset + explicit seek.
    file_descriptor.system_seek(0, IO::Seek::End) if file_descriptor.system_append?

    bytes_written
  end

  def wait_writable(file_descriptor : Crystal::System::FileDescriptor) : Nil
    raise NotImplementedError.new("Crystal::System::IOCP#wait_writable(FileDescriptor)")
  end

  def reopened(file_descriptor : Crystal::System::FileDescriptor) : Nil
    raise NotImplementedError.new("Crystal::System::IOCP#reopened(FileDescriptor)")
  end

  def shutdown(file_descriptor : Crystal::System::FileDescriptor) : Nil
  end

  def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
    LibC.CancelIoEx(file_descriptor.windows_handle, nil) unless file_descriptor.system_blocking?
    file_descriptor.file_descriptor_close
  end

  def socket(family : ::Socket::Family, type : ::Socket::Type, protocol : ::Socket::Protocol, blocking : Bool?) : {::Socket::Handle, Bool}
    blocking = true if blocking.nil?
    fd = System::Socket.socket(family, type, protocol, blocking)
    create_completion_port LibC::HANDLE.new(fd)
    {fd, blocking}
  end

  def socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : Tuple({::Socket::Handle, ::Socket::Handle}, Bool)
    raise NotImplementedError.new("Crystal::EventLoop::IOCP#socketpair")
  end

  private def wsa_buffer(bytes)
    wsabuf = LibC::WSABUF.new
    wsabuf.len = bytes.size
    wsabuf.buf = bytes.to_unsafe
    wsabuf
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    wsabuf = wsa_buffer(slice)

    bytes_read = System::IOCP.wsa_overlapped_operation(socket, socket.fd, "WSARecv", socket.read_timeout, connreset_is_error: false) do |overlapped|
      flags = 0_u32
      ret = LibC.WSARecv(socket.fd, pointerof(wsabuf), 1, out bytes_received, pointerof(flags), overlapped, nil)
      {ret, bytes_received}
    end

    bytes_read.to_i32
  end

  def wait_readable(socket : ::Socket) : Nil
    # NOTE: Windows 10+ has `ProcessSocketNotifications` to associate sockets to
    # a completion port and be notified of socket readiness. See
    # <https://learn.microsoft.com/en-us/windows/win32/winsock/winsock-socket-state-notifications>
    raise NotImplementedError.new("Crystal::System::IOCP#wait_readable(Socket)")
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    wsabuf = wsa_buffer(slice)

    bytes = System::IOCP.wsa_overlapped_operation(socket, socket.fd, "WSASend", socket.write_timeout) do |overlapped|
      ret = LibC.WSASend(socket.fd, pointerof(wsabuf), 1, out bytes_sent, 0, overlapped, nil)
      {ret, bytes_sent}
    end

    bytes.to_i32
  end

  def wait_writable(socket : ::Socket) : Nil
    # NOTE: Windows 10+ has `ProcessSocketNotifications` to associate sockets to
    # a completion port and be notified of socket readiness. See
    # <https://learn.microsoft.com/en-us/windows/win32/winsock/winsock-socket-state-notifications>
    raise NotImplementedError.new("Crystal::System::IOCP#wait_writable(Socket)")
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    wsabuf = wsa_buffer(slice)
    bytes_written = System::IOCP.wsa_overlapped_operation(socket, socket.fd, "WSASendTo", socket.write_timeout) do |overlapped|
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
    bytes_read = System::IOCP.wsa_overlapped_operation(socket, socket.fd, "WSARecvFrom", socket.read_timeout) do |overlapped|
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

  def accept(socket : ::Socket) : {::Socket::Handle, Bool}?
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
        System::Socket.setsockopt client_handle, LibC::SO_UPDATE_ACCEPT_CONTEXT, socket.fd

        true
      else
        false
      end
    end
  end

  def shutdown(socket : ::Socket) : Nil
  end

  def close(socket : ::Socket) : Nil
    raise NotImplementedError.new("Crystal::System::IOCP#close(Socket)")
  end
end
