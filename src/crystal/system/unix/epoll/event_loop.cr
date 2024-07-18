{% skip_file unless flag?(:linux) || flag?(:solaris) %}

require "./event_queue"
require "c/sys/eventfd"

class Crystal::Epoll::EventLoop < Crystal::EventLoop
  def initialize
    # mutex prevents parallel access to the queues
    @mutex = Thread::Mutex.new
    @events = EventQueue.new

    # the epoll instance
    @epoll = System::Epoll.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    @eventfd = LibC.eventfd(0, LibC::EFD_CLOEXEC)
    raise RuntimeError.from_errno("eventds") if @eventfd == -1

    @eventfd_event = Epoll::Event.interrupt(@eventfd)
    @eventfd_node = EventQueue::Node.new(@eventfd)
    @eventfd_node.add(@eventfd_event)

    # register permanent event
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = LibC::EPOLLIN
    epoll_event.data.ptr = @eventfd_node.as(Void*)
    @epoll.add(@eventfd, pointerof(epoll_event))
  end

  {% if flag?(:preview_mt) %}
    def after_fork_before_exec : Nil
      # must reset the mutexes since another thread may have acquired the lock
      # of one event loop, which would prevent closing file descriptors for
      # example.
      Thread.unsafe_each do |thread|
        break unless scheduler = thread.@scheduler
        break unless event_loop = scheduler.@event_loop
        event_loop.after_fork_before_exec_internal
      end
    end
  {% else %}
    def after_fork : Nil
      # re-create the epoll instance
      LibC.close(@epoll.@epfd)
      @epoll = System::Epoll.new

      # re-create eventfd to interrupt a run
      @interrupted.clear
      LibC.close(@eventfd)
      @eventfd = LibC.eventfd(0, LibC::EFD_CLOEXEC)
      raise RuntimeError.from_errno("eventds") if @eventfd == -1

      @eventfd_event = Epoll::Event.interrupt(@eventfd)
      @eventfd_node = EventQueue::Node.new(@eventfd)
      @eventfd_node.add(@eventfd_event)

      # re-register events:
      epoll_event = uninitialized LibC::EpollEvent

      epoll_event.events = LibC::EPOLLIN
      epoll_event.data.ptr = @eventfd_node.as(Void*)
      @epoll.add(@eventfd, pointerof(epoll_event))

      @events.each do |node|
        epoll_event.events = LibC::EPOLLET # | LibC::EPOLLEXCLUSIVE
        epoll_event.events |= LibC::EPOLLIN if node.readers?
        epoll_event.events |= LibC::EPOLLOUT if node.writers?
        epoll_event.data.ptr = node.as(Void*)
        @epoll.add(node.fd, pointerof(epoll_event))
      end
    end
  {% end %}

  protected def after_fork_before_exec_internal : Nil
    # re-create mutex: another thread may have hold the lock
    @mutex = Thread::Mutex.new
  end

  # {% if @top_level.has_constant?(:ExecutionContext) %}
  #  # prevents parallel runs of the event loop
  #  @run_mutex = Thread::Mutex.new

  #  # Waits for events and returns a list of runnable fibers.
  #  # Returns `nil` when there are no events to wait for.
  #  #
  #  # May return an empty list on spurious wakeup (we register both read & write
  #  # IO events, so we may be notified about "ready to write" when we're
  #  # "waiting for read").
  #  def run(blocking : Bool) : ExecutionContext::Queue?
  #    runnables = ExecutionContext::Queue.new

  #    @run_mutex.synchronize do
  #      return if @events.empty?
  #      run_internal(blocking) { |fiber| runnables.push(fiber) }
  #    end

  #    runnables
  #  end
  # {% else %}
  def run(blocking : Bool) : Bool
    if @events.empty?
      false
    else
      run_internal(blocking) # { |fiber| Crystal::Scheduler.enqueue(fiber) }
      true
    end
  end

  # {% end %}

  private def run_internal(blocking : Bool) : Nil
    buffer = uninitialized LibC::EpollEvent[32]

    Crystal.trace :evloop, "wait", blocking: blocking ? 1 : 0

    # wait for events (indefinitely when blocking)
    epoll_events = @epoll.wait(buffer.to_slice, timeout: blocking ? -1 : 0)

    # process each fd
    @mutex.synchronize do
      epoll_events.size.times do |i|
        epoll_event = epoll_events.to_unsafe + i
        node = epoll_event.value.data.ptr.as(EventQueue::Node)

        Crystal.trace :evloop, "event", fd: node.fd, events: epoll_event.value.events

        if node.fd == @eventfd
          LibC.eventfd_read(@eventfd, out _)
          @interrupted.clear
        elsif (epoll_event.value.events & (LibC::EPOLLERR | LibC::EPOLLHUP)) != 0
          dequeue_all(node) # { |fiber| yield fiber }
        else
          process(node, epoll_event) # { |fiber| yield fiber }
        end
      end
    end
  end

  private def dequeue_all(node)
    node.each do |event|
      case event.value.type
      in .io_read?, .io_write?
        cancel event.value.linked_event?
        # yield event.value.fiber
        Crystal::Scheduler.enqueue(event.value.fiber)
      in .sleep?, .io_timeout?, .select_timeout?
        raise "BUG: a timerfd file descriptor errored or got closed!"
      in .interrupt?
        raise "BUG: an eventfd file descriptor errored or got closed!"
      end
    end
    @events.delete(node)
    @epoll.delete(node.fd)
  end

  private def process(node, epoll_event)
    readable = (epoll_event.value.events & LibC::EPOLLIN) == LibC::EPOLLIN
    writable = (epoll_event.value.events & LibC::EPOLLOUT) == LibC::EPOLLOUT

    if readable && (event = node.dequeue_reader?)
      # wakeup one reader:
      # for :io_read we want to avoid a "thundering herd" issue
      # for :io_timeout, :select_timeout and :sleep there's only one reader
      readable = false

      if process_reader?(event)
        # yield event.value.fiber
        Crystal::Scheduler.enqueue(event.value.fiber)
      end
    end

    if writable && (event = node.dequeue_writer?)
      # wakeup one writer only (avoid "tundering herd"), cancel timeout (if any)
      writable = false
      cancel event.value.linked_event?

      # yield event.value.fiber
      Crystal::Scheduler.enqueue(event.value.fiber)
    end

    epoll_sync(node) do
      @events.delete(node)
    end

    # validate data integrity
    raise "BUG: #{node.fd} is ready for reading but no registered reader for #{node.fd}!\n" if readable
    raise "BUG: #{node.fd} is ready for writing but no registered writer for #{node.fd}!\n" if writable
  end

  private def process_reader?(event)
    case event.value.type
    when .io_read?
      # wakeup one reader, cancel timeout (if any)
      cancel event.value.linked_event?
    when .io_timeout?
      # cancel linked read/write event
      io_event = event.value.linked_event
      io_event.value.timed_out!
      cancel io_event
    when .select_timeout?
      # always dequeue the event but only enqueue the fiber if we win the
      # atomic CAS
      return false unless select_action = event.value.fiber.timeout_select_action
      event.value.fiber.timeout_select_action = nil
      return false unless select_action.time_expired?
    when .sleep?
      # nothing special
    end

    true
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    LibC.eventfd_write(@eventfd, 1) if @interrupted.test_and_set
  end

  # fiber

  class FiberEvent
    include Crystal::EventLoop::Event

    def initialize(@event_loop : Crystal::Epoll::EventLoop, fiber : Fiber, type : Epoll::Event::Type)
      @event = Epoll::Event.new(fiber.timerfd, fiber, type)
    end

    # sleeping or select timeout: arm timer & enqueue event
    def add(timeout : ::Time::Span?) : Nil
      @event.timerfd.set(::Time.monotonic + timeout)
      @event_loop.enqueue(pointerof(@event))
    end

    # select timeout has been cancelled: disarm timer & dequeue event
    def delete : Nil
      @event.timerfd.cancel
      @event_loop.dequeue(pointerof(@event))
    end

    def free : Nil
    end
  end

  def create_resume_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(self, fiber, :sleep)
  end

  def create_timeout_event(fiber : Fiber) : FiberEvent
    FiberEvent.new(self, fiber, :select_timeout)
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
      Thread.unsafe_each do |thread|
        break unless scheduler = thread.@scheduler
        break unless event_loop = scheduler.@event_loop
        event_loop.evented_close(file_descriptor.fd)
      end
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
      client_fd = LibC.accept4(socket.fd, nil, nil, LibC::SOCK_CLOEXEC)

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

  def connect(socket : ::Socket, address : ::Socket::Addrinfo | ::Socket::Address, timeout : ::Time::Span?) : IO::Error?
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
      # OPTIMIZE: iterating all eventloops ain't very efficient...
      Thread.unsafe_each do |thread|
        break unless scheduler = thread.@scheduler
        break unless event_loop = scheduler.@event_loop
        event_loop.evented_close(socket.fd)
      end
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
    # {% if @top_level.has_constant?(:ExecutionContext) %}
    #  runnables = ExecutionContext::Queue.new

    #  @mutex.synchronize do
    #    return unless node = @events[fd]?
    #    dequeue_all(node) { |fiber| runnables.push(fiber) }
    #  end

    #  ExecutionContext.enqueue(runnables) unless runnables.empty?
    # {% else %}
    @mutex.synchronize do
      return unless node = @events[fd]?
      dequeue_all(node) # { |fiber| Crystal::Scheduler.enqueue(fiber) }
    end
    # {% end %}
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

  private def wait(event_type : Epoll::Event::Type, fd : Int32, timeout : ::Time::Span?, &) : Nil
    fiber = Fiber.current
    io_event = Epoll::Event.new(fd, fiber, event_type)
    io_timeout = uninitialized Epoll::Event

    if timeout
      timerfd = fiber.timerfd
      timerfd.set(::Time.monotonic + timeout)

      io_timeout = Epoll::Event.new(timerfd, fiber, :io_timeout)
      io_timeout.linked_event = pointerof(io_event)
      io_event.linked_event = pointerof(io_timeout)
    end

    @mutex.synchronize do
      unsafe_enqueue pointerof(io_event)
      unsafe_enqueue pointerof(io_timeout) if timeout
    end

    Fiber.suspend

    if timeout && io_event.timed_out?
      yield
    end
  end

  private def check_open(io : IO)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  # queue internals

  protected def enqueue(event : Epoll::Event*)
    @mutex.synchronize { unsafe_enqueue(event) }
  end

  private def unsafe_enqueue(event : Epoll::Event*)
    Crystal.trace :evloop, "unsafe_enqueue", fd: event.value.fd, type: event.value.type.to_s
    node = @events.enqueue(event)
    epoll_sync(node) { raise "unreachable" }
  end

  # similar to #cancel, except we don't disarm the timer (already done)
  protected def dequeue(event : Epoll::Event*)
    @mutex.synchronize do
      node = @events.dequeue(event)
      epoll_sync(node) { @events.delete(node) }
    end
  end

  # unsafe, yields when there are no more events for fd
  private def epoll_sync(node)
    events = 0
    events |= LibC::EPOLLIN if node.readers?
    events |= LibC::EPOLLOUT if node.writers?

    # Crystal.trace :evloop, "epoll_sync", fd: node.fd, from: node.events, to: events

    if events == 0
      Crystal.trace :evloop, "epoll_ctl", op: "del", fd: node.fd
      @epoll.delete(node.fd)
      yield
    else
      epoll_event = uninitialized LibC::EpollEvent
      epoll_event.events = events | LibC::EPOLLET # | LibC::EPOLLEXCLUSIVE
      epoll_event.data.ptr = node.as(Void*)

      if node.events == 0
        Crystal.trace :evloop, "epoll_ctl", op: "add", fd: node.fd, events: events
        @epoll.add(node.fd, pointerof(epoll_event))
      else
        Crystal.trace :evloop, "epoll_ctl", op: "mod", fd: node.fd, events: events

        # quirk: we can't call EPOLL_CTL_MOD with EPOLLEXCLUSIVE
        @epoll.modify(node.fd, pointerof(epoll_event))
        # @epoll.delete(node.fd)
        # @epoll.add(node.fd, pointerof(epoll_event))
      end

      node.events = events
    end
  end

  private def cancel(event : Epoll::Event*)
    event.value.timerfd?.try(&.cancel)

    node = @events.dequeue(event)
    epoll_sync(node) { @events.delete(node) }
  end

  @[AlwaysInline]
  private def cancel(event : Nil)
  end
end
