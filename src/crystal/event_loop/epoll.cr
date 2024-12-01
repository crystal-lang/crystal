require "./polling"
require "../system/unix/epoll"
require "../system/unix/eventfd"
require "../system/unix/timerfd"

class Crystal::EventLoop::Epoll < Crystal::EventLoop::Polling
  def initialize
    # the epoll instance
    @epoll = System::Epoll.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    @eventfd = System::EventFD.new
    @epoll.add(@eventfd.fd, LibC::EPOLLIN, u64: @eventfd.fd.to_u64!)

    # we use timerfd to go below the millisecond precision of epoll_wait; it
    # also allows to avoid locking timers before every epoll_wait call
    @timerfd = System::TimerFD.new
    @epoll.add(@timerfd.fd, LibC::EPOLLIN, u64: @timerfd.fd.to_u64!)
  end

  def after_fork_before_exec : Nil
    super

    # O_CLOEXEC would close these automatically, but we don't want to mess with
    # the parent process fds (it would mess the parent evloop)
    @epoll.close
    @eventfd.close
    @timerfd.close
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      super

      # close inherited fds
      @epoll.close
      @eventfd.close
      @timerfd.close

      # create new fds
      @epoll = System::Epoll.new

      @interrupted.clear
      @eventfd = System::EventFD.new
      @epoll.add(@eventfd.fd, LibC::EPOLLIN, u64: @eventfd.fd.to_u64!)

      @timerfd = System::TimerFD.new
      @epoll.add(@timerfd.fd, LibC::EPOLLIN, u64: @timerfd.fd.to_u64!)
      system_set_timer(@timers.next_ready?)

      # re-add all registered fds
      Polling.arena.each_index { |fd, index| system_add(fd, index) }
    end
  {% end %}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    Crystal.trace :evloop, "run", blocking: blocking ? 1 : 0

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
        @interrupted.clear
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
    index = Polling::Arena::Index.new(epoll_event.value.data.u64)
    events = epoll_event.value.events

    Crystal.trace :evloop, "event", fd: index.index, index: index.to_i64, events: events

    Polling.arena.get?(index) do |pd|
      if (events & (LibC::EPOLLERR | LibC::EPOLLHUP)) != 0
        pd.value.@readers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        pd.value.@writers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        return
      end

      if (events & LibC::EPOLLRDHUP) == LibC::EPOLLRDHUP
        pd.value.@readers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      elsif (events & LibC::EPOLLIN) == LibC::EPOLLIN
        pd.value.@readers.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      end

      if (events & LibC::EPOLLOUT) == LibC::EPOLLOUT
        pd.value.@writers.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
      end
    end
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) if @interrupted.test_and_set
  end

  protected def system_add(fd : Int32, index : Polling::Arena::Index) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: fd, index: index.to_i64
    events = LibC::EPOLLIN | LibC::EPOLLOUT | LibC::EPOLLRDHUP | LibC::EPOLLET
    @epoll.add(fd, events, u64: index.to_u64)
  end

  protected def system_del(fd : Int32, closing = true) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd)
  end

  protected def system_del(fd : Int32, closing = true, &) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd) { yield }
  end

  private def system_set_timer(time : Time::Span?) : Nil
    if time
      @timerfd.set(time)
    else
      @timerfd.cancel
    end
  end
end
