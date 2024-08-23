require "../evented/event_loop"
require "../kqueue"

class Crystal::Kqueue::EventLoop < Crystal::Evented::EventLoop
  INTERRUPT_IDENTIFIER = 9

  {% unless LibC.has_constant?(:EVFILT_USER) %}
    @pipe = uninitialized LibC::Int[2]
  {% end %}

  def initialize
    super

    # the kqueue instance
    @kqueue = System::Kqueue.new

    # notification to interrupt a run
    @interrupted = Atomic::Flag.new
    {% unless LibC.has_constant?(:EVFILT_USER) %}
      @pipe = System::FileDescriptor.system_pipe
      @kqueue.kevent(@pipe[0], LibC::EVFILT_READ, LibC::EV_ADD)
    {% end %}
  end

  def after_fork_before_exec : Nil
    super

    # O_CLOEXEC would close these automatically, _but_ we don't want to mess
    # with the parent process fds (that could mess the parent evloop)

    {% unless flag?(:darwin) || flag?(:dragonfly) %}
      # kqueue isn't inherited by fork on darwin/dragonfly, but is inherited
      # on other BSD
      @kqueue.close
    {% end %}
    {% unless LibC.has_constant?(:EVFILT_USER) %}
      @pipe.each { |fd| LibC.close(fd) }
    {% end %}
  end

  {% unless flag?(:preview_mt) %}
    def after_fork : Nil
      super

      {% unless flag?(:darwin) || flag?(:dragonfly) %}
        # kqueue isn't inherited by fork on darwin/dragonfly, but is inherited
        # on other BSD
        @kqueue.close
      {% end %}
      @kqueue = System::Kqueue.new

      @interrupted.clear
      {% unless LibC.has_constant?(:EVFILT_USER) %}
        @pipe.each { |fd| LibC.close(fd) }
        @pipe = System::FileDescriptor.system_pipe
        @kqueue.kevent(@pipe[0], LibC::EVFILT_READ, LibC::EV_ADD)
      {% end %}

      system_set_timer(@timers.next_ready?)

      # FIXME: must re-add all fds (but we don't know about 'em)
      raise "BUG: fork is unsupported in evented event-loop mode"
    end
  {% end %}

  private def system_run(blocking : Bool) : Nil
    buffer = uninitialized LibC::Kevent[128]

    Crystal.trace :evloop, "wait", blocking: blocking ? 1 : 0
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
        process(kevent)
      end
    end

    process_timers(timer_triggered)
  end

  private def process_interrupt?(kevent)
    {% if LibC.has_constant?(:EVFILT_USER) %}
      if kevent.value.filter == LibC::EVFILT_USER
        @interrupted.clear if kevent.value.ident == INTERRUPT_IDENTIFIER
        return true
      end
    {% else %}
      if kevent.value.filter == LibC::EVFILT_READ && kevent.value.ident == @pipe[0]
        @interrupted.clear
        byte = 0_u8
        ret = LibC.read(@pipe[0], pointerof(byte), 1)
        raise RuntimeError.from_errno("read") if ret == -1
        return true
      end
    {% end %}
    false
  end

  private def process(kevent : LibC::Kevent*) : Nil
    pd = kevent.value.udata.as(Evented::PollDescriptor*)

    {% if flag?(:tracing) %}
      Crystal.trace :evloop, "event", fd: pd.value.fd, filter: kevent.value.filter, flags: kevent.value.flags, fflags: kevent.value.fflags
    {% end %}

    if (kevent.value.fflags & LibC::EV_EOF) == LibC::EV_EOF
      # apparently some systems may report EOF on write with EVFILT_READ instead
      # of EVFILT_WRITE, so let's wake all waiters:
      pd.value.@readers.consume_each { |event| resume_io(event) }
      pd.value.@writers.consume_each { |event| resume_io(event) }
      return
    end

    case kevent.value.filter
    when LibC::EVFILT_READ
      if (kevent.value.fflags & LibC::EV_ERROR) == LibC::EV_ERROR
        # OPTIMIZE: pass errno (kevent.data) through PollDescriptor
        pd.value.@readers.consume_each { |event| resume_io(event) }
      elsif event = pd.value.@readers.ready!
        resume_io(event)
      end
    when LibC::EVFILT_WRITE
      if (kevent.value.fflags & LibC::EV_ERROR) == LibC::EV_ERROR
        # OPTIMIZE: pass errno (kevent.data) through PollDescriptor
        pd.value.@writers.consume_each { |event| resume_io(event) }
      elsif event = pd.value.@writers.ready!
        resume_io(event)
      end
    end
  end

  def interrupt : Nil
    return unless @interrupted.test_and_set

    {% if LibC.has_constant?(:EVFILT_USER) %}
      @kqueue.kevent(
        INTERRUPT_IDENTIFIER,
        LibC::EVFILT_USER,
        LibC::EV_ADD | LibC::EV_ONESHOT,
        LibC::NOTE_FFCOPY | LibC::NOTE_TRIGGER | 1_u16)
    {% else %}
      byte = 1_u8
      ret = LibC.write(@pipe[1], pointerof(byte), sizeof(typeof(byte)))
      raise RuntimeError.from_errno("write") if ret == -1
    {% end %}
  end

  private def system_add(fd : Int32, ptr : Pointer) : Nil
    Crystal.trace :evloop, "kevent", op: "add", fd: fd

    # register both read and write events
    kevents = uninitialized LibC::Kevent[2]
    2.times do |i|
      kevent = kevents.to_unsafe + i
      filter = i == 0 ? LibC::EVFILT_READ : LibC::EVFILT_WRITE
      System::Kqueue.set(kevent, fd, filter, LibC::EV_ADD | LibC::EV_CLEAR, udata: ptr)
    end

    @kqueue.kevent(kevents.to_slice) do
      # we broadly add file descriptors to kqueue whenever we open them, but
      # sometimes the other end is closed and registration can fail (e.g.
      # stdio).
      #
      # we can safely discard these errors since further read or write to these
      # file descriptors will fail with the same error and the evloop will never
      # try to wait.
      unless Errno.value.in?(Errno::ENODEV, Errno::EPIPE, Errno::EINVAL)
        raise RuntimeError.from_errno("kevent")
      end
    end
  end

  private def system_del(fd : Int32) : Nil
    # nothing to do: close(2) will do the job
  end

  private def system_set_timer(time : Time::Span?) : Nil
    if time
      flags = LibC::EV_ADD | LibC::EV_ONESHOT | LibC::EV_CLEAR
      t = time - Time.monotonic
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

    # use the evloop address as the unique identifier for the timer kevent
    ident = LibC::SizeT.new!(self.as(Void*).address)
    @kqueue.kevent(ident, LibC::EVFILT_TIMER, flags, fflags, data) do
      raise RuntimeError.from_errno("kevent") unless Errno.value == Errno::ENOENT
    end
  end
end
