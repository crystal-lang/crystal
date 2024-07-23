{% skip_file unless flag?(:linux) || flag?(:solaris) %}

require "../evented/event_loop"
require "../epoll"
require "../eventfd"
require "../timerfd"

class Crystal::Epoll::EventLoop < Crystal::Evented::EventLoop
  def initialize
    super

    # the epoll instance
    @epoll = System::Epoll.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    @eventfd = System::EventFD.new
    @eventfd_event = Evented::Event.new(:system, @eventfd.fd)
    @eventfd_node = Evented::EventQueue::Node.new(@eventfd.fd)
    @eventfd_node.add(pointerof(@eventfd_event))
    system_add(@eventfd_node)

    # timer to go below the millisecond prevision of epoll_wait
    @timerfd = System::TimerFD.new
    @timerfd_event = Evented::Event.new(:system, @timerfd.fd)
    @timerfd_node = Evented::EventQueue::Node.new(@timerfd.fd)
    @timerfd_node.add(pointerof(@timerfd_event))
    system_add(@timerfd_node)
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      super

      # close inherited fds
      @epoll.close
      @eventfd.close
      @timerfd.close

      # re-create the epoll instance
      @epoll = System::Epoll.new

      # re-create and re-register system events
      @interrupted.clear

      # notification to interrupt a run
      @eventfd = System::EventFD.new
      @eventfd_event = Evented::Event.new(:system, @eventfd.fd)
      @eventfd_node = Evented::EventQueue::Node.new(@eventfd.fd)
      @eventfd_node.add(pointerof(@eventfd_event))
      system_add(@eventfd_node)

      # timer to go below the millisecond prevision of epoll_wait
      @timerfd = System::TimerFD.new
      @timerfd_event = Evented::Event.new(:system, @timerfd.fd)
      @timerfd_node = Evented::EventQueue::Node.new(@timerfd.fd)
      @timerfd_node.add(pointerof(@timerfd_event))
      system_add(@timerfd_node)

      # re-register events
      @events.each do |node|
        node.registrations = :none
        system_sync(node) { raise "unreachable" }
      end
    end
  {% end %}

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
        node = epoll_event.value.data.ptr.as(Evented::EventQueue::Node)

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

    system_sync(node) do
      @events.delete(node)
    end

    # validate data integrity
    System.print_error "BUG: fd=%d is ready for reading but no registered reader!\n", node.fd if readable
    System.print_error "BUG: fd=%d is ready for writing but no registered writer!\n", node.fd if writable
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) if @interrupted.test_and_set
  end

  private def system_add(node : Evented::EventQueue::Node) : Nil
    epoll_event = uninitialized LibC::EpollEvent
    epoll_event.events = LibC::EPOLLIN
    epoll_event.data.ptr = node.as(Void*)
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: node.fd
    @epoll.add(node.fd, pointerof(epoll_event))
  end

  private def system_delete(node : Evented::EventQueue::Node) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: node.fd
    @epoll.delete(node.fd)
  end

  # unsafe, yields when there are no more events for fd
  private def system_sync(node : Evented::EventQueue::Node, &) : Nil
    events = 0
    registrations = Evented::EventQueue::Node::Registrations::NONE

    if node.readers?
      events |= LibC::EPOLLIN
      registrations |= :read
    end

    if node.writers?
      events |= LibC::EPOLLOUT
      registrations |= :write
    end

    if events == 0
      Crystal.trace :evloop, "epoll_ctl", op: "del", fd: node.fd
      @epoll.delete(node.fd)
      yield
    else
      epoll_event = uninitialized LibC::EpollEvent
      epoll_event.events = events | LibC::EPOLLET # | LibC::EPOLLEXCLUSIVE
      epoll_event.data.ptr = node.as(Void*)

      if node.registrations.none?
        Crystal.trace :evloop, "epoll_ctl", op: "add", fd: node.fd, events: events
        @epoll.add(node.fd, pointerof(epoll_event))
      else
        Crystal.trace :evloop, "epoll_ctl", op: "mod", fd: node.fd, events: events

        # quirk: we can't call EPOLL_CTL_MOD with EPOLLEXCLUSIVE
        @epoll.modify(node.fd, pointerof(epoll_event))
        # @epoll.delete(node.fd)
        # @epoll.add(node.fd, pointerof(epoll_event))
      end

      node.registrations = registrations
    end
  end
end
