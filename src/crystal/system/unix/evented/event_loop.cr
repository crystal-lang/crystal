require "./*"

abstract class Crystal::Evented::EventLoop < Crystal::EventLoop
  def initialize
    @mutex = Thread::Mutex.new
    @events = EventQueue.new
    @timers = Timers.new
  end

  {% if flag?(:preview_mt) %}
    protected def self.each(&)
      Thread.unsafe_each do |thread|
        next unless scheduler = thread.@scheduler
        next unless event_loop = scheduler.@event_loop
        yield event_loop
      end
    end

    # must reset the mutexes since another thread may have acquired the lock of
    # one event loop, which would prevent closing file descriptors for example.
    def after_fork_before_exec : Nil
      EventLoop.each do |event_loop|
        if event_loop.responds_to?(:after_fork_before_exec_internal)
          event_loop.after_fork_before_exec_internal
        end
      end
    end

    protected def after_fork_before_exec_internal : Nil
      # re-create mutex: another thread may have hold the lock
      @mutex = Thread::Mutex.new
    end
  {% else %}
    def after_fork : Nil
      # NOTE: fixes an EPERM when calling `pthread_mutex_unlock` in #dequeue
      # called from `Fiber#resume_event.free` when running std specs.
      @mutex = Thread::Mutex.new
    end
  {% end %}

  def run(blocking : Bool) : Bool
    if @events.empty? && @timers.empty?
      false
    else
      run_internal(blocking)
      true
    end
  end

  private def dequeue_all(node)
    node.each do |event|
      case event.value.type
      when .io_read?, .io_write?
        @timers.delete(event) if event.value.time?
        Crystal::Scheduler.enqueue(event.value.fiber)
      else
        System.print_error "BUG: fd=%d got closed but it was an event loop system fd!\n", node.fd
      end
    end
    @events.delete(node)
    system_delete(node)
  end

  private def process_timer(event)
    case event.value.type
    when .io_read?, .io_write?
      # reached timeout: cancel the IO event
      event.value.timed_out!
      unsafe_dequeue_io_event(event)
    when .select_timeout?
      # always dequeue the event but only enqueue the fiber if we win the
      # atomic CAS
      return unless select_action = event.value.fiber.timeout_select_action
      event.value.fiber.timeout_select_action = nil
      return unless select_action.time_expired?
      event.value.fiber.@timeout_event.as(FiberEvent).clear
    when .sleep?
      # cleanup
      event.value.fiber.@resume_event.as(FiberEvent).clear
    else
      raise RuntimeError.new("BUG: unexpected event in timers: #{event.value}%s\n")
    end

    Crystal::Scheduler.enqueue(event.value.fiber)
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) if @interrupted.test_and_set
  end

  # fiber

  def create_resume_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(fiber, :sleep)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(fiber, :select_timeout)
  end

  # file descriptor

  def read(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    size = evented_read(file_descriptor.fd, slice, file_descriptor.@read_timeout) do
      check_open(file_descriptor)
    end

    if size == -1
      if Errno.value == Errno::EBADF
        raise IO::Error.new("File not open for reading", target: file_descriptor)
      else
        raise IO::Error.from_errno("read", target: file_descriptor)
      end
    else
      size.to_i32
    end
  end

  def write(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    size = evented_write(file_descriptor.fd, slice, file_descriptor.@write_timeout) do
      check_open(file_descriptor)
    end

    if size == -1
      if Errno.value == Errno::EBADF
        raise IO::Error.new("File not open for writing", target: file_descriptor)
      else
        raise IO::Error.from_errno("write", target: file_descriptor)
      end
    else
      size.to_i32
    end
  end

  def close(file_descriptor : System::FileDescriptor) : Nil
    {% if flag?(:preview_mt) %}
      # MT: one event loop may be waiting on the fd while another thread closes
      # the fd, so we must iterate all event loops to remove all events before
      # we close
      # OPTIMIZE: blindly iterating each eventloop ain't very efficient...
      EventLoop.each(&.evented_close(file_descriptor.fd))
    {% else %}
      evented_close(file_descriptor.fd)
    {% end %}
  end

  # socket

  def read(socket : ::Socket, slice : Bytes) : Int32
    size = evented_read(socket.fd, slice, socket.@read_timeout) do
      check_open(socket)
    end
    raise IO::Error.from_errno("read", target: socket) if size == -1
    size
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    size = evented_write(socket.fd, slice, socket.@write_timeout) do
      check_open(socket)
    end
    raise IO::Error.from_errno("write", target: socket) if size == -1
    size
  end

  def accept(socket : ::Socket) : ::Socket::Handle?
    loop do
      client_fd =
        {% if LibC.has_method?(:accept4) %}
          LibC.accept4(socket.fd, nil, nil, LibC::SOCK_CLOEXEC)
        {% else %}
          # we may fail to set FD_CLOEXEC between `accept` and `fcntl` but we
          # can't call `Crystal::System::Socket.lock_read` because the socket
          # might be in blocking mode and accept would block until the socket
          # receives a connection.
          #
          # we could lock when `socket.blocking?` is false, but another thread
          # could change the socket back to blocking mode between the condition
          # check and the `accept` call.
          LibC.accept(socket.fd, nil, nil).tap do |fd|
            System::Socket.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC) unless fd == -1
          end
        {% end %}

      return client_fd unless client_fd == -1
      return if socket.closed?

      if Errno.value == Errno::EAGAIN
        wait_readable(socket.fd, socket.@read_timeout) do
          raise IO::TimeoutError.new("Accept timed out")
        end
        return if socket.closed?
      else
        raise ::Socket::Error.from_errno("accept")
      end
    end
  end

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : Time::Span?) : IO::Error?
    loop do
      ret = LibC.connect(socket.fd, address, address.size)
      return unless ret == -1

      case Errno.value
      when Errno::EISCONN
        return
      when Errno::EINPROGRESS, Errno::EALREADY
        wait_writable(socket.fd, timeout) do
          return IO::TimeoutError.new("Connect timed out")
        end
      else
        return ::Socket::ConnectError.from_errno("connect")
      end
    end
  end

  def send_to(socket : ::Socket, slice : Bytes, address : ::Socket::Address) : Int32
    bytes_sent = LibC.sendto(socket.fd, slice.to_unsafe.as(Void*), slice.size, 0, address, address.size)
    raise ::Socket::Error.from_errno("Error sending datagram to #{address}") if bytes_sent == -1
    bytes_sent.to_i32
  end

  def receive_from(socket : ::Socket, slice : Bytes) : {Int32, ::Socket::Address}
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)

    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = socket.family
    sockaddr.value = copy
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    loop do
      size = LibC.recvfrom(socket.fd, slice, slice.size, 0, sockaddr, pointerof(addrlen))
      if size == -1
        if Errno.value == Errno::EAGAIN
          wait_readable(socket.fd, socket.@read_timeout)
          check_open(socket)
        else
          raise IO::Error.from_errno("recvfrom", target: socket)
        end
      else
        return {size.to_i32, ::Socket::Address.from(sockaddr, addrlen)}
      end
    end
  end

  def close(socket : ::Socket) : Nil
    {% if flag?(:preview_mt) %}
      # MT: one event loop may be waiting on the fd while another thread closes
      # the fd, so we must iterate all event loops to remove all events before
      # we close
      # OPTIMIZE: iterating all eventloops ain't very efficient...
      EventLoop.each(&.evented_close(socket.fd))
    {% else %}
      evented_close(socket.fd)
    {% end %}
  end

  # evented internals

  private def evented_read(fd : Int32, slice : Bytes, timeout : Time::Span?, &) : Int32
    loop do
      ret = LibC.read(fd, slice, slice.size)
      if ret == -1 && Errno.value == Errno::EAGAIN
        wait_readable(fd, timeout)
        yield
      else
        return ret.to_i
      end
    end
  end

  private def evented_write(fd : Int32, slice : Bytes, timeout : Time::Span?, &) : Int32
    loop do
      ret = LibC.write(fd, slice, slice.size)
      if ret == -1 && Errno.value == Errno::EAGAIN
        wait_writable(fd, timeout)
        yield
      else
        return ret.to_i
      end
    end
  end

  protected def evented_close(fd : Int32)
    @mutex.synchronize do
      if node = @events[fd]?
        dequeue_all(node)
      end
    end
  end

  private def wait_readable(fd : Int32, timeout : Time::Span? = nil) : Nil
    wait(:io_read, fd, timeout) { raise IO::TimeoutError.new("Read timed out") }
  end

  private def wait_readable(fd : Int32, timeout : Time::Span? = nil, &) : Nil
    wait(:io_read, fd, timeout) { yield }
  end

  private def wait_writable(fd : Int32, timeout : Time::Span? = nil) : Nil
    wait(:io_write, fd, timeout) { raise IO::TimeoutError.new("Write timed out") }
  end

  private def wait_writable(fd : Int32, timeout : Time::Span? = nil, &) : Nil
    wait(:io_write, fd, timeout) { yield }
  end

  private def wait(event_type : Evented::Event::Type, fd : Int32, timeout : Time::Span?, &) : Nil
    io_event = Evented::Event.new(event_type, fd, Fiber.current, timeout)
    enqueue pointerof(io_event)
    Fiber.suspend
    yield if timeout && io_event.timed_out?
  end

  private def check_open(io : IO)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  # queue internals

  protected def enqueue(event : Evented::Event*)
    @mutex.synchronize do
      case event.value.type
      in .io_read?, .io_write?
        node = @events.enqueue(event)
        system_sync(node) { raise "unreachable" }
        @timers.add(event) if event.value.time?
      in .sleep?, .select_timeout?
        @timers.add(event)
      in .system?
        raise RuntimeError.new("BUG: system event can't be enqueued #{event.value}")
      end
    end
  end

  protected def dequeue(event : Evented::Event*)
    @mutex.synchronize do
      case event.value.type
      in .io_read?, .io_write?
        unsafe_dequeue_io_event(event)
        @timers.delete(event) if event.value.time?
      in .sleep?, .select_timeout?
        @timers.delete(event)
      in .system?
        raise RuntimeError.new("BUG: system event can't be dequeued #{event.value}")
      end
    end
  end

  private def unsafe_dequeue_io_event(event : Evented::Event*)
    node = @events.dequeue(event)
    system_sync(node) { @events.delete(node) }
  end

  # system internals

  # NOTE: can't enable the following abstract methods, because they break
  # compilation

  # private abstract def system_delete(node : Evented::EventQueue::Node) : Nil
  # private abstract def system_sync(node : Evented::EventQueue::Node) : Nil
end
