{% skip_file unless flag?(:linux) || flag?(:solaris) %}

require "./event_queue"
require "./timers"
require "../eventfd"
require "../timerfd"

class Crystal::Epoll::EventLoop < Crystal::EventLoop
  @eventfd_node : EventQueue::Node
  @timerfd_node : EventQueue::Node

  def initialize
    # mutex prevents parallel access to the queues
    @mutex = Thread::Mutex.new
    @events = EventQueue.new
    @timers = Epoll::Timers.new

    # the epoll instance
    @epoll = System::Epoll.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    @eventfd = System::EventFD.new
    @eventfd_event = Epoll::Event.system(@eventfd.fd)
    @eventfd_node = EventQueue::Node.new(@eventfd.fd).tap(&.add(@eventfd_event))

    # timer to go below the millisecond prevision of epoll_wait
    @timerfd = System::TimerFD.new
    @timerfd_event = Epoll::Event.system(@timerfd.fd)
    @timerfd_node = EventQueue::Node.new(@timerfd.fd).tap(&.add(@timerfd_event))

    # register system events (permanent)
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = LibC::EPOLLIN

    epoll_event.data.ptr = @eventfd_node.as(Void*)
    @epoll.add(@eventfd.fd, pointerof(epoll_event))

    epoll_event.data.ptr = @timerfd_node.as(Void*)
    @epoll.add(@timerfd.fd, pointerof(epoll_event))
  end

  {% if flag?(:preview_mt) %}
    def after_fork_before_exec : Nil
      # must reset the mutexes since another thread may have acquired the lock
      # of one event loop, which would prevent closing file descriptors for
      # example.
      Thread.unsafe_each do |thread|
        break unless scheduler = thread.@scheduler
        break unless event_loop = scheduler.@event_loop

        if event_loop.responds_to?(:after_fork_before_exec_internal)
          event_loop.after_fork_before_exec_internal
        end
      end
    end
  {% else %}
    def after_fork : Nil
      # close inherited fds
      @epoll.close
      @eventfd.close
      @timerfd.close

      # re-create the epoll instance
      @epoll = System::Epoll.new

      # re-create system events
      @interrupted.clear

      @eventfd = System::EventFD.new
      @eventfd_event = Epoll::Event.system(@eventfd.fd)
      @eventfd_node = EventQueue::Node.new(@eventfd.fd).tap(&.add(@eventfd_event))

      @timerfd = System::TimerFD.new
      @timerfd_event = Epoll::Event.system(@timerfd.fd)
      @timerfd_node = EventQueue::Node.new(@timerfd.fd).tap(&.add(@timerfd_event))

      # re-register system events
      epoll_event = uninitialized LibC::EpollEvent
      epoll_event.events = LibC::EPOLLIN

      epoll_event.data.ptr = @eventfd_node.as(Void*)
      @epoll.add(@eventfd.fd, pointerof(epoll_event))

      epoll_event.data.ptr = @timerfd_node.as(Void*)
      @epoll.add(@timerfd.fd, pointerof(epoll_event))

      # re-register pending events
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

  def run(blocking : Bool) : Bool
    if @events.empty? && @timers.empty?
      false
    else
      run_internal(blocking)
      true
    end
  end

  private def run_internal(blocking : Bool) : Nil
    buffer = uninitialized LibC::EpollEvent[32]

    Crystal.trace :evloop, "wait", blocking: blocking ? 1 : 0

    if blocking && (time = @mutex.synchronize { @timers.next_ready? })
      # epoll_wait only has milliseconds precision, so we use a timerfd for
      # timeout; arm it to the next ready time
      @timerfd.set(time)
    end

    # wait for events (indefinitely when blocking)
    epoll_events = @epoll.wait(buffer.to_slice, timeout: blocking ? -1 : 0)

    @mutex.synchronize do
      # process events
      epoll_events.size.times do |i|
        epoll_event = epoll_events.to_unsafe + i
        node = epoll_event.value.data.ptr.as(EventQueue::Node)

        Crystal.trace :evloop, "event", fd: node.fd, events: epoll_event.value.events

        if node.fd == @eventfd.fd
          @eventfd.read
          @interrupted.clear
        elsif node.fd == @timerfd.fd
          # nothing special
        elsif (epoll_event.value.events & (LibC::EPOLLERR | LibC::EPOLLHUP)) != 0
          dequeue_all(node)
        else
          process(node, epoll_event)
        end
      end

      # process timers
      @timers.dequeue_ready do |event|
        process_timer(event)
      end
    end
  end

  private def dequeue_all(node)
    node.each do |event|
      case event.value.type
      when .io_read?, .io_write?
        @timers.delete(event) if event.value.time?
        Crystal::Scheduler.enqueue(event.value.fiber)
      else
        raise "BUG: a system file descriptor (fd=#{node.fd}) got closed!"
      end
    end
    @events.delete(node)
    @epoll.delete(node.fd)
  end

  private def process(node, epoll_event)
    readable = (epoll_event.value.events & LibC::EPOLLIN) == LibC::EPOLLIN
    writable = (epoll_event.value.events & LibC::EPOLLOUT) == LibC::EPOLLOUT

    if readable && (event = node.dequeue_reader?)
      readable = false
      @timers.delete(event) if event.value.time?
      Crystal::Scheduler.enqueue(event.value.fiber)
    end

    if writable && (event = node.dequeue_writer?)
      writable = false
      @timers.delete(event) if event.value.time?
      Crystal::Scheduler.enqueue(event.value.fiber)
    end

    epoll_sync(node) do
      @events.delete(node)
    end

    # validate data integrity
    raise "BUG: #{node.fd} is ready for reading but no registered reader for #{node.fd}!\n" if readable
    raise "BUG: #{node.fd} is ready for writing but no registered writer for #{node.fd}!\n" if writable
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
    when .sleep?
      # nothing special
    else
      raise "BUG: unexpected event in timers: #{event.value}"
    end

    Crystal::Scheduler.enqueue(event.value.fiber)
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) if @interrupted.test_and_set
  end

  # fiber

  class FiberEvent
    include Crystal::EventLoop::Event

    def initialize(@event_loop : Crystal::Epoll::EventLoop, fiber : Fiber, type : Epoll::Event::Type)
      @event = Epoll::Event.new(-1, fiber, type)
    end

    # sleep or select timeout
    def add(timeout : ::Time::Span?) : Nil
      return unless timeout # FIXME: why can timeout be nil?!

      @event.time = ::Time.monotonic + timeout
      @event_loop.enqueue(pointerof(@event))
    end

    # select timeout has been cancelled
    def delete : Nil
      @event_loop.dequeue(pointerof(@event))
    end

    # fiber died
    def free : Nil
      @event_loop.dequeue(pointerof(@event))
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

  private def wait(event_type : Epoll::Event::Type, fd : Int32, timeout : ::Time::Span?, &) : Nil
    io_event = Epoll::Event.new(fd, Fiber.current, event_type, timeout)
    enqueue pointerof(io_event)
    Fiber.suspend
    yield if timeout && io_event.timed_out?
  end

  private def check_open(io : IO)
    raise IO::Error.new("Closed stream") if io.closed?
  end

  # queue internals

  protected def enqueue(event : Epoll::Event*)
    @mutex.synchronize do
      case event.value.type
      in .io_read?, .io_write?
        node = @events.enqueue(event)
        epoll_sync(node) { raise "unreachable" }
        @timers.add(event) if event.value.time?
      in .sleep?, .select_timeout?
        @timers.add(event)
      in .system?
        raise "BUG: system event can't be enqueued #{event.value}"
      end
    end
  end

  protected def dequeue(event : Epoll::Event*)
    @mutex.synchronize do
      case event.value.type
      in .io_read?, .io_write?
        unsafe_dequeue_io_event(event)
        @timers.delete(event) if event.value.time?
      in .sleep?, .select_timeout?
        @timers.delete(event)
      in .system?
        raise "BUG: system event can't be dequeued #{event.value}"
      end
    end
  end

  private def unsafe_dequeue_io_event(event : Epoll::Event*)
    node = @events.dequeue(event)
    epoll_sync(node) { @events.delete(node) }
  end

  # unsafe, yields when there are no more events for fd
  private def epoll_sync(node, &)
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
end
