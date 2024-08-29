require "./*"
require "../../../arena"

# OPTIMIZE: collect fibers & canceled timers, delete canceled timers when
# processing timers, and eventually enqueue all fibers; it would avoid repeated
# lock/unlock timers on each #resume_io and allow to replace individual fiber
# enqueues with a single batch enqueue (simpler).
abstract class Crystal::Evented::EventLoop < Crystal::EventLoop
  def initialize
    {% if flag?(:preview_mt) %} @run_lock = Atomic::Flag.new {% end %}
    @lock = SpinLock.new

    # NOTE: timers and the arena are globals
    @timers = Timers.new
    @arena = Arena(PollDescriptor).new
  end

  # must reset the mutexes since another thread may have acquired the lock of
  # one event loop, which would prevent closing file descriptors for example.
  def after_fork_before_exec : Nil
    {% if flag?(:preview_mt) %} @run_lock.clear {% end %}
    @lock = SpinLock.new
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      # NOTE: fixes an EPERM when calling `pthread_mutex_unlock` in #dequeue
      # called from `Fiber#resume_event.free` when running std specs.
      {% if flag?(:preview_mt) %} @run_lock.clear {% end %}
      @lock = SpinLock.new
    end
  {% end %}

  # thread unsafe: must hold `@run_mutex` before calling!
  def run(blocking : Bool) : Bool
    system_run(blocking)
    true
  end

  def try_lock?(&) : Bool
    {% if flag?(:preview_mt) %}
      if @run_lock.test_and_set
        begin
          yield
          true
        ensure
          @run_lock.clear
        end
      else
        false
      end
    {% else %}
      yield
      true
    {% end %}
  end

  def try_run?(blocking : Bool) : Bool
    try_lock? { run(blocking) }
  end

  # fiber

  def create_resume_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(fiber, :sleep)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(fiber, :select_timeout)
  end

  # file descriptor

  def delete(file_descriptor : System::FileDescriptor) : Nil
    fd = file_descriptor.fd
    @arena.free(fd) { }
    system_del(fd)
  end

  def read(file_descriptor : System::FileDescriptor, slice : Bytes) : Int32
    size = evented_read(file_descriptor, slice, file_descriptor.@read_timeout)

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
    size = evented_write(file_descriptor, slice, file_descriptor.@write_timeout)

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
    evented_close(file_descriptor)
  end

  # socket

  def delete(socket : ::Socket) : Nil
    fd = socket.fd
    @arena.free(fd) { }
    system_del(fd)
  end

  def read(socket : ::Socket, slice : Bytes) : Int32
    size = evented_read(socket, slice, socket.@read_timeout)
    raise IO::Error.from_errno("read", target: socket) if size == -1
    size
  end

  def write(socket : ::Socket, slice : Bytes) : Int32
    size = evented_write(socket, slice, socket.@write_timeout)
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
        wait_readable(socket, socket.@read_timeout) do
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
        wait_writable(socket, timeout) do
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
          wait_readable(socket, socket.@read_timeout)
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
    evented_close(socket)
  end

  # evented internals

  private def evented_read(io, slice : Bytes, timeout : Time::Span?) : Int32
    loop do
      ret = LibC.read(io.fd, slice, slice.size)
      if ret == -1 && Errno.value == Errno::EAGAIN
        wait_readable(io, timeout)
        check_open(io)
      else
        return ret.to_i
      end
    end
  end

  private def evented_write(io, slice : Bytes, timeout : Time::Span?) : Int32
    loop do
      ret = LibC.write(io.fd, slice, slice.size)
      if ret == -1 && Errno.value == Errno::EAGAIN
        wait_writable(io, timeout)
        check_open(io)
      else
        return ret.to_i
      end
    end
  end

  protected def evented_close(io)
    @arena.free(io.fd) do |pd|
      pd.value.@readers.consume_each { |event| resume_io(event) }
      pd.value.@writers.consume_each { |event| resume_io(event) }
    end
    system_del(io.fd)
  end

  private def wait_readable(io, timeout = nil) : Nil
    wait(:io_read, io.fd, :readers, timeout) { raise IO::TimeoutError.new("Read timed out") }
  end

  private def wait_readable(io, timeout = nil, &) : Nil
    wait(:io_read, io.fd, :readers, timeout) { yield }
  end

  private def wait_writable(io, timeout = nil) : Nil
    wait(:io_write, io.fd, :writers, timeout) { raise IO::TimeoutError.new("Write timed out") }
  end

  private def wait_writable(io, timeout = nil, &) : Nil
    wait(:io_write, io.fd, :writers, timeout) { yield }
  end

  private macro wait(type, fd, waiters, timeout, &)
    # lazily register the fd
    %pd, %gen_index = @arena.lazy_allocate({{fd}}) do |_, gen_index|
      system_add({{fd}}, gen_index)
    end

    # create an event (on the stack)
    %event = Evented::Event.new({{type}}, Fiber.current, %gen_index, {{timeout}})

    # try to add the event to the waiting list
    # don't wait if the waiter has already been marked ready (see Waiters#add)
    return unless %pd.value.@{{waiters.id}}.add(pointerof(%event))

    if %event.wake_at?
      add_timer(pointerof(%event))

      Fiber.suspend

      if %event.timed_out?
        return {{yield}}
      else
        # nothing to do: either the timer triggered which means it was dequeued,
        # or `#resume_io` was called to resume the IO and the timer got deleted
        # from the timers before the fiber got reenqueued.
        #
        # TODO: consider a quick check to verify whether the event is still
        # queued and panic when it happens: the event is put on the stack and we
        # can't access after this method returns!
      end
    else
      Fiber.suspend
    end

    {% if flag?(:preview_mt) %}
      # we can safely reset readyness here, since we're about to retry the actual syscall
      %pd.value.@{{waiters.id}}.@ready.set(false, :relaxed)
    {% end %}
  end

  private def check_open(io : IO)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  # internals

  protected def add_timer(event : Evented::Event*)
    @lock.sync do
      is_next_ready = @timers.add(event)
      system_set_timer(event.value.wake_at) if is_next_ready
    end
  end

  protected def delete_timer(event : Evented::Event*)
    @lock.sync do
      was_next_ready = @timers.delete(event)
      system_set_timer(@timers.next_ready?) if was_next_ready
    end
  end

  # OPTIMIZE: Collect events with the lock then process them after releasing the
  # lock, which should be thread-safe as long as @run_lock is locked.
  private def process_timers(timer_triggered : Bool) : Nil
    # events = PointerLinkedList(Event).new
    size = 0

    @lock.sync do
      @timers.dequeue_ready do |event|
        # events << event
        process_timer(event)
        size += 1
      end

      unless size == 0 && timer_triggered
        system_set_timer(@timers.next_ready?)
      end
    end

    # events.each { |event| process_timer(event) }
  end

  private def process_timer(event : Evented::Event*)
    fiber = event.value.fiber

    case event.value.type
    when .io_read?
      # reached read timeout: cancel io event
      event.value.timed_out!
      pd = @arena.get(event.value.gen_index)
      pd.value.@readers.delete(event)
    when .io_write?
      # reached write timeout: cancel io event
      event.value.timed_out!
      pd = @arena.get(event.value.gen_index)
      pd.value.@writers.delete(event)
    when .select_timeout?
      # always dequeue the event but only enqueue the fiber if we win the
      # atomic CAS
      return unless select_action = fiber.timeout_select_action
      fiber.timeout_select_action = nil
      return unless select_action.time_expired?
      fiber.@timeout_event.as(FiberEvent).clear
    when .sleep?
      # cleanup
      fiber.@resume_event.as(FiberEvent).clear
    else
      raise RuntimeError.new("BUG: unexpected event in timers: #{event.value}%s\n")
    end

    Crystal::Scheduler.enqueue(fiber)
  end

  # Helper to resume the fiber associated to an IO event and remove the event
  # from timers if applicable.
  private def resume_io(event : Evented::Event*) : Nil
    delete_timer(event) if event.value.wake_at?
    Crystal::Scheduler.enqueue(event.value.fiber)
  end

  # system internals

  private abstract def system_run(blocking : Bool) : Nil
  private abstract def system_add(fd : Int32, gen_index : Int64) : Nil
  private abstract def system_del(fd : Int32) : Nil
  private abstract def system_set_timer(time : Time::Span?) : Nil
end
