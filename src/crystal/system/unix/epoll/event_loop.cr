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
    @epoll.add(@eventfd.fd, LibC::EPOLLIN)

    # we use timerfd to go below the millisecond precision of epoll_wait; it
    # also allows to avoid locking timers before every epoll_wait call
    @timerfd = System::TimerFD.new
    @epoll.add(@timerfd.fd, LibC::EPOLLIN)
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
      @epoll.add(@eventfd.fd, LibC::EPOLLIN)

      @timerfd = System::TimerFD.new
      @epoll.add(@timerfd.fd, LibC::EPOLLIN)
      system_set_timer(@timers.next_ready?)

      # re-add all registered fds
      @arena.each_index { |fd| system_add(fd) }
    end
  {% end %}

  private def system_run(blocking : Bool) : Nil
    Crystal.trace :evloop, "wait", blocking: blocking ? 1 : 0

    # wait for events (indefinitely when blocking)
    buffer = uninitialized LibC::EpollEvent[128]
    epoll_events = @epoll.wait(buffer.to_slice, timeout: blocking ? -1 : 0)

    timer_triggered = false

    # process events
    epoll_events.size.times do |i|
      epoll_event = epoll_events.to_unsafe + i

      case epoll_event.value.data.fd
      when @eventfd.fd
        # TODO: panic if epoll_event.value.events != LibC::EPOLLIN (could be EPOLLERR or EPLLHUP)
        Crystal.trace :evloop, "interrupted"
        @eventfd.read
        # OPTIMIZE: only reset interrupted before a blocking wait
        @interrupted.clear
      when @timerfd.fd
        # TODO: panic if epoll_event.value.events != LibC::EPOLLIN (could be EPOLLERR or EPLLHUP)
        Crystal.trace :evloop, "timer"
        timer_triggered = true
      else
        process(epoll_event)
      end
    end

    process_timers(timer_triggered)
  end

  private def process(epoll_event : LibC::EpollEvent*) : Nil
    fd = epoll_event.value.data.fd
    events = epoll_event.value.events
    pd = @arena.get?(fd)

    {% if flag?(:tracing) %}
      Crystal.trace :evloop, "event", fd: fd, events: events, pd: pd
    {% end %}
    return unless pd

    if (events & (LibC::EPOLLERR | LibC::EPOLLHUP)) != 0
      pd.value.@readers.consume_each { |event| resume_io(event) }
      pd.value.@writers.consume_each { |event| resume_io(event) }
      return
    end

    if (events & LibC::EPOLLRDHUP) == LibC::EPOLLRDHUP
      pd.value.@readers.consume_each { |event| resume_io(event) }
    elsif (events & LibC::EPOLLIN) == LibC::EPOLLIN
      if event = pd.value.@readers.ready!
        resume_io(event)
      end
    end

    if (events & LibC::EPOLLOUT) == LibC::EPOLLOUT
      if event = pd.value.@writers.ready!
        resume_io(event)
      end
    end
  end

  def interrupt : Nil
    # the atomic makes sure we only write once
    @eventfd.write(1) if @interrupted.test_and_set
  end

  private def system_add(fd : Int32) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: fd
    @epoll.add(fd, LibC::EPOLLIN | LibC::EPOLLOUT | LibC::EPOLLRDHUP | LibC::EPOLLET)
  end

  def system_del(fd : Int32) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd)
  end

  private def system_set_timer(time : Time::Span?) : Nil
    if time
      @timerfd.set(time)
    else
      @timerfd.cancel
    end
  end
end
