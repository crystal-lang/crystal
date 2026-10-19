require "c/sys/wait"
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
    @eventfd.write(1) unless @interrupted.swap(true, :relaxed)
  end

  # process interface, see Crystal::EventLoop::Process

  def wait(process : System::Process) : ::Process::Status
    {% if flag?(:solaris) %}
      raise NotImplementedError.new("Crystal::EventLoop::Epoll#wait(process)")
    {% else %}
      siginfo = uninitialized LibC::SiginfoT

      if pidfd = process.pidfd?
        pidfd_wait(pidfd, pointerof(siginfo))
      else
        Fiber.syscall do
          ret = LibC.waitid(LibC::P_PID, process.pid, pointerof(siginfo), LibC::WEXITED)
          raise RuntimeError.from_errno("waitid") if ret == -1
        end
      end

      if siginfo.si_code == LibC::CLD_EXITED
        ::Process::Status[siginfo.si_status]
      else
        ::Process::Status[Signal.new(siginfo.si_status)]
      end
    {% end %}
  end

  def pidfd_blocking?
    false
  end

  private def pidfd_wait(pidfd, siginfo)
    io = IO::FileDescriptor.new(handle: pidfd, close_on_finalize: false)

    loop do
      Errno.value = Errno::NONE
      ret = LibC.waitid(LibC::P_PIDFD, pidfd, siginfo, LibC::WEXITED)
      return if ret == 0

      case errno = Errno.value
      when Errno::EAGAIN
        wait_readable(io, nil) { }
      else
        raise RuntimeError.from_os_error("waitid", errno)
      end
    ensure
      self.class.remove_impl(io)
    end
  end

  # internals

  protected def system_add(fd : Int32, index : Polling::Arena::Index) : RegisteredEvents
    Crystal.trace :evloop, "epoll_ctl", op: "add", fd: fd, index: index.to_i64
    events = LibC::EPOLLIN | LibC::EPOLLOUT | LibC::EPOLLRDHUP | LibC::EPOLLET
    @epoll.add(fd, events, u64: index.to_u64)
    RegisteredEvents::READ | RegisteredEvents::WRITE
  end

  protected def system_del(fd : Int32, closing = true) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd)
  end

  protected def system_del(fd : Int32, closing = true, &) : Nil
    Crystal.trace :evloop, "epoll_ctl", op: "del", fd: fd
    @epoll.delete(fd) { yield }
  end

  private def system_set_timer(time : Time::Instant?) : Nil
    if time
      @timerfd.set(time)
    else
      @timerfd.cancel
    end
  end
end
