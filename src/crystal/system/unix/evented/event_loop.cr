require "./*"
require "./arena"

module Crystal::System::FileDescriptor
  # user data (generation index for the arena)
  property __evloop_data : Int64 = -1_i64
end

module Crystal::System::Socket
  # user data (generation index for the arena)
  property __evloop_data : Int64 = -1_i64
end

module Crystal::Evented
  # The choice of a generational arena permits to avoid pushing raw pointers into
  # IO objects into kernel data structures that are unknown to the GC, and to
  # safely check whether the allocation is still valid before trying to
  # dereference the pointer. Since `PollDescriptor` also doesn't have pointers to
  # the actual IO object, it won't prevent the GC from collecting lost IO objects
  # (and spares us from using
  #
  # To a lesser extent, it also allows to keep the `PollDescriptor` allocated
  # together in the same region, and polluting the IO object itself with specific
  # evloop data (except for the generation index).
  #
  # We assume the fd is unique (OS guarantee) and that the OS will always reuse
  # the lowest fds before growing, so the memory region should never grow too
  # big without a good reason (i.e. we need that many fds at that time). This
  # assumption allows the arena to not have to keep a list of free indexes.
  protected class_getter arena = Arena(PollDescriptor).new(max_fds)

  private def self.max_fds : Int32
    if LibC.getrlimit(LibC::RLIMIT_NOFILE, out rlimit) == -1
      raise RuntimeError.from_errno("getrlimit(RLIMIT_NOFILE)")
    end
    rlimit.rlim_max.clamp(..Int32::MAX).to_i32!
  end
end

# Polling EventLoop.
#
# This is the abstract interface that implements `Crystal::EventLoop` for
# polling based UNIX targets, such as epoll (linux), kqueue (bsd), or poll
# (posix) syscalls. This class only implements the generic parts for the
# external world to interact with the loop. A specific implementation is
# required to handle the actual syscalls.
#
# The event loop registers the fd into the kernel data structures when an IO
# operation would block, then keeps it there until the fd is closed.
#
# NOTE: the fds must have `O_NONBLOCK` set.
#
# It is possible to have multiple event loop instances, but an fd can only be in
# one instance at a time. When trying to block from another loop, the fd will be
# removed from its associated loop and added to the current one (this is
# automatic). Trying to move a fd to another loop with pending waiters is
# unsupported and will raise an exception. See `PollDescriptor#remove`.
#
# A timed event such as sleep or select timeout follows the following logic:
#
# 1. create an `Event` (actually reuses it, see `FiberChannel`);
# 2. register the event in `@timers`;
# 3. supend the current fiber.
#
# The timer will eventually trigger and resume the fiber.
# When an IO operation on fd would block, the loop follows the following logic:
#
# 1. register the fd (once);
# 2. create an `Event`;
# 3. suspend the current fiber;
#
# When the IO operation is ready, the fiber will eventually be resumed (one
# fiber at a time). If it's an IO operation, the operation is tried again which
# may block again, until the operation succeeds or an error occured (e.g.
# closed, broken pipe).
#
# If the IO operation has a timeout, the event is also registered into `@timers`
# before suspending the fiber, then after resume it will raise
# `IO::TimeoutError` if the event timed out, and continue otherwise.
#
# OPTIMIZE: collect fibers & canceled timers, delete canceled timers when
# processing timers, and eventually enqueue all fibers; it would avoid repeated
# lock/unlock timers on each #resume_io and allow to replace individual fiber
# enqueues with a single batch enqueue (simpler).
abstract class Crystal::Evented::EventLoop < Crystal::EventLoop
  {% if flag?(:preview_mt) %}
    @run_lock = Atomic::Flag.new # protects parallel runs
  {% end %}

  def initialize
    @lock = SpinLock.new # protects parallel accesses to @timers
    @timers = Timers.new
  end

  # reset the mutexes since another thread may have acquired the lock of one
  # event loop, which would prevent closing file descriptors for example.
  def after_fork_before_exec : Nil
    {% if flag?(:preview_mt) %} @run_lock.clear {% end %}
    @lock = SpinLock.new
  end

  {% unless flag?(:preview_mt) %}
    # no parallelism issues, but let's clean-up anyway
    def after_fork : Nil
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

  # fiber interface, see Crystal::EventLoop

  def create_resume_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(self, fiber, :sleep)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(self, fiber, :select_timeout)
  end

  # file descriptor interface, see Crystal::EventLoop::FileDescriptor

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

  def remove(file_descriptor : System::FileDescriptor) : Nil
    Evented.arena.free(file_descriptor.fd) do |pd|
      pd.value.remove(file_descriptor.fd) { } # ignore system error
      file_descriptor.__evloop_data = -1_i64
    end
  end

  # socket interface, see Crystal::EventLoop::Socket

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

  def remove(socket : ::Socket) : Nil
    Evented.arena.free(socket.fd) do |pd|
      pd.value.remove(socket.fd) { } # ignore system error
      socket.__evloop_data = -1_i64
    end
  end

  # internals: IO

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
    Evented.arena.free(io.fd) do |pd|
      pd.value.@readers.consume_each do |event|
        pd.value.@event_loop.try(&.resume_io(event))
      end

      pd.value.@writers.consume_each do |event|
        pd.value.@event_loop.try(&.resume_io(event))
      end

      pd.value.remove(io.fd)
      io.__evloop_data = -1_i64
    end
  end

  private def wait_readable(io, timeout = nil) : Nil
    wait(:io_read, io, :readers, timeout) { raise IO::TimeoutError.new("Read timed out") }
  end

  private def wait_readable(io, timeout = nil, &) : Nil
    wait(:io_read, io, :readers, timeout) { yield }
  end

  private def wait_writable(io, timeout = nil) : Nil
    wait(:io_write, io, :writers, timeout) { raise IO::TimeoutError.new("Write timed out") }
  end

  private def wait_writable(io, timeout = nil, &) : Nil
    wait(:io_write, io, :writers, timeout) { yield }
  end

  private macro wait(type, io, waiters, timeout, &)
    # get or allocate the poll descriptor
    if (%gen_index = {{io}}.__evloop_data) >= 0
      %pd = Evented.arena.get(%gen_index)
    else
      %pd, %gen_index = Evented.arena.lazy_allocate({{io}}.fd) do |pd, gen_index|
        # register the fd with the event loop (once), it should usually merely add
        # the fd to the current evloop but may "transfer" the ownership from
        # another event loop:
        {{io}}.__evloop_data = gen_index
        pd.value.take_ownership(self, {{io}}.fd, gen_index)
      end
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
        # can't access it after this method returns!
      end
    else
      Fiber.suspend
    end

    {% if flag?(:preview_mt) %}
      # we can safely reset readyness here, since we're about to retry the
      # actual syscall
      %pd.value.@{{waiters.id}}.@ready.set(false, :relaxed)
    {% end %}
  end

  private def check_open(io : IO)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  # internals: timers

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

  # Helper to resume the fiber associated to an IO event and remove the event
  # from timers if applicable.
  protected def resume_io(event : Evented::Event*) : Nil
    delete_timer(event) if event.value.wake_at?
    Crystal::Scheduler.enqueue(event.value.fiber)
  end

  # Process ready timers.
  #
  # Shall be called after processing IO events. IO events with a timeout that
  # have succeeded shall already have been removed from `@timers` otherwise the
  # fiber could be resumed twice!
  #
  # OPTIMIZE: collect events with the lock then process them after releasing the
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
      pd = Evented.arena.get(event.value.gen_index)
      pd.value.@readers.delete(event)
    when .io_write?
      # reached write timeout: cancel io event
      event.value.timed_out!
      pd = Evented.arena.get(event.value.gen_index)
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

  # internals: system

  # Process ready events and timers.
  #
  # The loop must always process ready events and timers before returning. When
  # *blocking* is `true` the loop must wait for events to become ready (possibly
  # indefinitely); when `false` the loop shall return immediately.
  #
  # The `PollDescriptor` of IO events can be retrieved using the *gen_index*
  # from the system event's user data.
  private abstract def system_run(blocking : Bool) : Nil

  # Add *fd* to the polling system, setting *gen_index* as user data.
  protected abstract def system_add(fd : Int32, gen_index : Int64) : Nil

  # Remove *fd* from the polling system. Must raise a `RuntimeError` on error.
  protected abstract def system_del(fd : Int32) : Nil

  # Remove *fd* from the polling system. Must yield on error.
  protected abstract def system_del(fd : Int32, &) : Nil

  # Arm a timer to interrupt a run at *time*. Set to `nil` to disarm the timer.
  private abstract def system_set_timer(time : Time::Span?) : Nil
end
