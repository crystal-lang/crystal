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
      Evented.arena.each { |fd, gen_index| system_add(fd, gen_index) }
    end
  {% end %}

  private def system_run(blocking : Bool) : Nil
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
    gen_index = epoll_event.value.data.u64.unsafe_as(Int64)
    events = epoll_event.value.events

    {% if flag?(:tracing) %}
      fd = (gen_index >> 32).to_i32!
      Crystal.trace :evloop, "event", fd: fd, gen_index: gen_index, events: events
    {% end %}

    pd = Evented.arena.get(gen_index)

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

  protected def system_add(fd : Int32, gen_index : Int64) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: fd, gen_index: gen_index
    events = LibC::EPOLLIN | LibC::EPOLLOUT | LibC::EPOLLRDHUP | LibC::EPOLLET
    @epoll.add(fd, events, u64: gen_index.unsafe_as(UInt64))
  end

  protected def system_del(fd : Int32) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd)
  end

  protected def system_del(fd : Int32, &) : Nil
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
