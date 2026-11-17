require "./polling"
require "../system/unix/epoll"
require "../system/unix/eventfd"
require "../system/unix/timerfd"

class Crystal::EventLoop::Epoll < Crystal::EventLoop::Polling
  def initialize(parallelism : Int32)
    # the epoll instance
    @epoll = System::Epoll.new

    # notification to interrupt a run
    @interrupted = Atomic(Bool).new(false)
    @eventfd = System::EventFD.new
    @epoll.add(@eventfd.fd, LibC::EPOLLIN, u64: @eventfd.fd.to_u64!)

    # we use timerfd to go below the millisecond precision of epoll_wait; it
    # also allows to avoid locking timers before every epoll_wait call
    @timerfd = System::TimerFD.new
    @epoll.add(@timerfd.fd, LibC::EPOLLIN, u64: @timerfd.fd.to_u64!)
  end

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    Crystal.trace :evloop, "run", blocking: blocking

    # wait for events (indefinitely when blocking)
    buffer = uninitialized LibC::EpollEvent[128]
    epoll_events = @epoll.wait(buffer.to_slice, timeout: blocking ? -1 : 0)

    timer_triggered = false

    # process events
    epoll_events.size.times do |i|
      epoll_event = epoll_events.to_unsafe + i

      case epoll_event.value.data.u64
      when @eventfd.fd
        # TODO: panic if epoll_event.value.events != LibC::EPOLLIN (could be EPOLLERR or EPLLHUP)
        Crystal.trace :evloop, "interrupted"
        @eventfd.read
        @interrupted.set(false, :relaxed)
      when @timerfd.fd
        # TODO: panic if epoll_event.value.events != LibC::EPOLLIN (could be EPOLLERR or EPLLHUP)
        Crystal.trace :evloop, "timer"
        timer_triggered = true
      else
        process_io(epoll_event) { |fiber| yield fiber }
      end
    end

    # OPTIMIZE: only process timers when timer_triggered (?)
    process_timers(timer_triggered) { |fiber| yield fiber }
  end

  private def process_io(epoll_event : LibC::EpollEvent*, &) : Nil
    {% begin %}
      # manual devirtualization of IO+ into concrete types
      case io = Pointer(Void).new(epoll_event.value.data.u64).as(IO)
      when IO::FileDescriptor
        process_io_impl(io, epoll_event.value.events) { |fiber| yield fiber }
      {% if @top_level.has_constant?(:Socket) %}
      when ::Socket
        process_io_impl(io, epoll_event.value.events) { |fiber| yield fiber }
      {% end %}
      else
        raise "BUG: expected IO::FileDescriptor or Socket but got #{io.class.name}"
      end
    {% end %}
  end

  private def process_io_impl(io, events, &)
    Crystal.trace :evloop, "event", fd: io.fd, io: io.as(Void*), type: io.class.name, events: events

    io.__poll_descriptor do |pd|
      if (events & (LibC::EPOLLERR | LibC::EPOLLHUP)) != 0
        pd.value.@reader.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        pd.value.@writer.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        return
      end

      if (events & LibC::EPOLLRDHUP) == LibC::EPOLLRDHUP
        pd.value.@reader.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      elsif (events & LibC::EPOLLIN) == LibC::EPOLLIN
        pd.value.@reader.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      end

      if (events & LibC::EPOLLOUT) == LibC::EPOLLOUT
        pd.value.@writer.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      end
    end
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) unless @interrupted.swap(true, :relaxed)
  end

  protected def system_add(io) : RegisteredEvents
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: io.fd, io: io.as(Void*), type: io.class.name
    events = LibC::EPOLLIN | LibC::EPOLLOUT | LibC::EPOLLRDHUP | LibC::EPOLLET
    @epoll.add(io.fd, events, u64: io.as(Void*).address.to_u64!)
    RegisteredEvents::READ | RegisteredEvents::WRITE
  end

  protected def system_del(io, closing = true) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: io.fd, io: io.as(Void*), type: io.class.name
    @epoll.delete(io.fd)
  end

  protected def system_del(io, closing = true, &) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: io.fd, io: io.as(Void*), type: io.class.name
    @epoll.delete(io.fd) { yield }
  end

  private def system_set_timer(time : Time::Instant?) : Nil
    if time
      @timerfd.set(time)
    else
      @timerfd.cancel
    end
  end
end
