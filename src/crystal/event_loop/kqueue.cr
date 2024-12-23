require "./polling"
require "../system/unix/kqueue"

class Crystal::EventLoop::Kqueue < Crystal::EventLoop::Polling
  # the following are arbitrary numbers to identify specific events
  INTERRUPT_IDENTIFIER =  9
  TIMER_IDENTIFIER     = 10

  {% unless LibC.has_constant?(:EVFILT_USER) %}
    @pipe = uninitialized LibC::Int[2]
  {% end %}

  def initialize
    # the kqueue instance
    @kqueue = System::Kqueue.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new

    {% if LibC.has_constant?(:EVFILT_USER) %}
      @kqueue.kevent(
        INTERRUPT_IDENTIFIER,
        LibC::EVFILT_USER,
        LibC::EV_ADD | LibC::EV_ENABLE | LibC::EV_CLEAR)
    {% else %}
      @pipe = System::FileDescriptor.system_pipe
      @kqueue.kevent(@pipe[0], LibC::EVFILT_READ, LibC::EV_ADD)
    {% end %}
  end

  def after_fork_before_exec : Nil
    super

    # O_CLOEXEC would close these automatically but we don't want to mess with
    # the parent process fds (that would mess the parent evloop)

    # kqueue isn't inherited by fork on darwin/dragonfly, but we still close
    @kqueue.close

    {% unless LibC.has_constant?(:EVFILT_USER) %}
      @pipe.each { |fd| LibC.close(fd) }
    {% end %}
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      super

      # kqueue isn't inherited by fork on darwin/dragonfly, but we still close
      @kqueue.close
      @kqueue = System::Kqueue.new

      @interrupted.clear

      {% if LibC.has_constant?(:EVFILT_USER) %}
        @kqueue.kevent(
          INTERRUPT_IDENTIFIER,
          LibC::EVFILT_USER,
          LibC::EV_ADD | LibC::EV_ENABLE | LibC::EV_CLEAR)
      {% else %}
        @pipe.each { |fd| LibC.close(fd) }
        @pipe = System::FileDescriptor.system_pipe
        @kqueue.kevent(@pipe[0], LibC::EVFILT_READ, LibC::EV_ADD)
      {% end %}

      system_set_timer(@timers.next_ready?)

      # re-add all registered fds
      Polling.arena.each_index { |fd, index| system_add(fd, index) }
    end
  {% end %}

  private def system_run(blocking : Bool, & : Fiber ->) : Nil
    buffer = uninitialized LibC::Kevent[128]

    Crystal.trace :evloop, "run", blocking: blocking ? 1 : 0
    timeout = blocking ? nil : Time::Span.zero
    kevents = @kqueue.wait(buffer.to_slice, timeout)

    timer_triggered = false

    # process events
    kevents.size.times do |i|
      kevent = kevents.to_unsafe + i

      if process_interrupt?(kevent)
        # nothing special
      elsif kevent.value.filter == LibC::EVFILT_TIMER
        # nothing special
        timer_triggered = true
      else
        process_io(kevent) { |fiber| yield fiber }
      end
    end

    # OPTIMIZE: only process timers when timer_triggered (?)
    process_timers(timer_triggered) { |fiber| yield fiber }
  end

  private def process_interrupt?(kevent)
    {% if LibC.has_constant?(:EVFILT_USER) %}
      if kevent.value.filter == LibC::EVFILT_USER
        @interrupted.clear if kevent.value.ident == INTERRUPT_IDENTIFIER
        return true
      end
    {% else %}
      if kevent.value.filter == LibC::EVFILT_READ && kevent.value.ident == @pipe[0]
        ident = 0
        ret = LibC.read(@pipe[0], pointerof(ident), sizeof(Int32))
        raise RuntimeError.from_errno("read") if ret == -1
        @interrupted.clear if ident == INTERRUPT_IDENTIFIER
        return true
      end
    {% end %}
    false
  end

  private def process_io(kevent : LibC::Kevent*, &) : Nil
    index =
      {% if flag?(:bits64) %}
        Polling::Arena::Index.new(kevent.value.udata.address)
      {% else %}
        # assuming 32-bit target: rebuild the arena index
        Polling::Arena::Index.new(kevent.value.ident.to_i32!, kevent.value.udata.address.to_u32!)
      {% end %}

    Crystal.trace :evloop, "event", fd: kevent.value.ident, index: index.to_i64,
      filter: kevent.value.filter, flags: kevent.value.flags, fflags: kevent.value.fflags

    Polling.arena.get?(index) do |pd|
      if (kevent.value.fflags & LibC::EV_EOF) == LibC::EV_EOF
        # apparently some systems may report EOF on write with EVFILT_READ instead
        # of EVFILT_WRITE, so let's wake all waiters:
        pd.value.@readers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        pd.value.@writers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        return
      end

      case kevent.value.filter
      when LibC::EVFILT_READ
        if (kevent.value.fflags & LibC::EV_ERROR) == LibC::EV_ERROR
          # OPTIMIZE: pass errno (kevent.data) through PollDescriptor
          pd.value.@readers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        else
          pd.value.@readers.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        end
      when LibC::EVFILT_WRITE
        if (kevent.value.fflags & LibC::EV_ERROR) == LibC::EV_ERROR
          # OPTIMIZE: pass errno (kevent.data) through PollDescriptor
          pd.value.@writers.ready_all { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        else
          pd.value.@writers.ready_one { |event| unsafe_resume_io(event) { |fiber| yield fiber } }
        end
      end
    end
  end

  def interrupt : Nil
    return unless @interrupted.test_and_set

    {% if LibC.has_constant?(:EVFILT_USER) %}
      @kqueue.kevent(INTERRUPT_IDENTIFIER, LibC::EVFILT_USER, 0, LibC::NOTE_TRIGGER)
    {% else %}
      ident = INTERRUPT_IDENTIFIER
      ret = LibC.write(@pipe[1], pointerof(ident), sizeof(Int32))
      raise RuntimeError.from_errno("write") if ret == -1
    {% end %}
  end

  protected def system_add(fd : Int32, index : Polling::Arena::Index) : Nil
    Crystal.trace :evloop, "kevent", op: "add", fd: fd, index: index.to_i64

    # register both read and write events
    kevents = uninitialized LibC::Kevent[2]
    {LibC::EVFILT_READ, LibC::EVFILT_WRITE}.each_with_index do |filter, i|
      kevent = kevents.to_unsafe + i
      udata =
        {% if flag?(:bits64) %}
          Pointer(Void).new(index.to_u64)
        {% else %}
          # assuming 32-bit target: pass the generation as udata (ident is the fd/index)
          Pointer(Void).new(index.generation)
        {% end %}
      System::Kqueue.set(kevent, fd, filter, LibC::EV_ADD | LibC::EV_CLEAR, udata: udata)
    end

    @kqueue.kevent(kevents.to_slice) do
      raise RuntimeError.from_errno("kevent")
    end
  end

  protected def system_del(fd : Int32, closing = true) : Nil
    system_del(fd, closing) do
      raise RuntimeError.from_errno("kevent")
    end
  end

  protected def system_del(fd : Int32, closing = true, &) : Nil
    return if closing # nothing to do: close(2) will do the cleanup

    Crystal.trace :evloop, "kevent", op: "del", fd: fd

    # unregister both read and write events
    kevents = uninitialized LibC::Kevent[2]
    {LibC::EVFILT_READ, LibC::EVFILT_WRITE}.each_with_index do |filter, i|
      kevent = kevents.to_unsafe + i
      System::Kqueue.set(kevent, fd, filter, LibC::EV_DELETE)
    end

    @kqueue.kevent(kevents.to_slice) do
      raise RuntimeError.from_errno("kevent")
    end
  end

  private def system_set_timer(time : Time::Span?) : Nil
    if time
      flags = LibC::EV_ADD | LibC::EV_ONESHOT | LibC::EV_CLEAR

      seconds, nanoseconds = System::Time.monotonic
      now = Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
      t = time - now

      data =
        {% if LibC.has_constant?(:NOTE_NSECONDS) %}
          t.total_nanoseconds.to_i64!.clamp(0..)
        {% else %}
          # legacy BSD (and DragonFly) only have millisecond precision
          t.positive? ? t.total_milliseconds.to_i64!.clamp(1..) : 0
        {% end %}
    else
      flags = LibC::EV_DELETE
      data = 0_u64
    end

    fflags =
      {% if LibC.has_constant?(:NOTE_NSECONDS) %}
        LibC::NOTE_NSECONDS
      {% else %}
        0
      {% end %}

    @kqueue.kevent(TIMER_IDENTIFIER, LibC::EVFILT_TIMER, flags, fflags, data) do
      raise RuntimeError.from_errno("kevent") unless Errno.value == Errno::ENOENT
    end
  end
end
