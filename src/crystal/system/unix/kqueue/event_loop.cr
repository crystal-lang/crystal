require "../evented/event_loop"
require "../kqueue"

class Crystal::Kqueue::EventLoop < Crystal::Evented::EventLoop
  INTERRUPT_IDENTIFIER = 9

  {% unless LibC.has_constant?(:EVFILT_USER) %}
    @pipe = uninitialized LibC::Int[2]
  {% end %}

  def initialize
    super

    @kqueue = System::Kqueue.new

    @interrupted = Atomic::Flag.new
    {% unless LibC.has_constant?(:EVFILT_USER) %}
      @pipe = System::FileDescriptor.system_pipe
      @kqueue.kevent(@pipe[0], LibC::EVFILT_READ, LibC::EV_ADD)
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

      @events.each do |node|
        node.registrations = :none
        system_sync(node) { raise "unreachable" }
      end
    end
  {% end %}

  private def run_internal(blocking : Bool) : Nil
    changes = uninitialized LibC::Kevent[0]
    buffer = uninitialized LibC::Kevent[32]
    timeout = self.run_timeout(blocking)

    Crystal.trace :evloop, "wait", blocking: blocking ? 1 : 0, timeout: timeout.try(&.total_nanoseconds.to_i64)
    kevents = @kqueue.kevent(changes.to_slice, buffer.to_slice, timeout)

    @mutex.synchronize do
      # process events
      kevents.size.times do |i|
        kevent = kevents.to_unsafe + i

        # handle system event first (it doesn't have a node)
        next if process_interrupt?(kevent)

        node = kevent.value.udata.as(Evented::EventQueue::Node)
        Crystal.trace :evloop, "event", fd: node.fd, filter: kevent.value.filter

        if (kevent.value.fflags & LibC::EV_EOF) == LibC::EV_EOF
          dequeue_all(node)
        elsif process_error?(kevent)
          dequeue_all(node)
        else
          process_io_event(node, kevent)

          # OPTIMIZE: sync all kevents with a *single* kevent syscall *after*
          # processing all the kevents
          system_sync(node) do
            @events.delete(node)
          end
        end
      end

      # process timers
      @timers.dequeue_ready do |event|
        process_timer(event)
      end
    end
  end

  private def run_timeout(blocking)
    return Time::Span.zero unless blocking

    if time = @mutex.synchronize { @timers.next_ready? }
      # wait until next timer / don't wait if next timer is already in the past
      now = Time.monotonic
      return time > now ? time - now : Time::Span.zero
    end

    # wait indefinitely
    nil
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

  private def process_error?(kevent)
    if (kevent.value.fflags & LibC::EV_ERROR) == LibC::EV_ERROR
      case errno = Errno.new(kevent.value.data.to_i32!)
      when Errno::EPERM, Errno::EPIPE
        return true
      else
        raise RuntimeError.from_os_error("kevent", errno)
      end
    end
    false
  end

  private def process_io_event(node, kevent)
    case kevent.value.filter
    when LibC::EVFILT_READ
      if event = node.dequeue_reader?
        @timers.delete(event) if event.value.time?
        Crystal::Scheduler.enqueue(event.value.fiber)
      else
        System.print_error "BUG: fd=%d is ready for reading but no registered reader!\n", node.fd
      end
    when LibC::EVFILT_WRITE
      if event = node.dequeue_writer?
        @timers.delete(event) if event.value.time?
        Crystal::Scheduler.enqueue(event.value.fiber)
      else
        System.print_error "BUG: fd=%d is ready for writing but no registered writer!\n", node.fd
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

  private def system_delete(node : Evented::EventQueue::Node) : Nil
    kevents = uninitialized LibC::Kevent[2]
    kevent = kevents.to_unsafe
    size = 0

    if node.registrations.read?
      System::Kqueue.set(kevent, node.fd, LibC::EVFILT_READ, LibC::EV_DELETE, udata: node)
      size += 1
      kevent += 1
    end

    if node.registrations.write?
      System::Kqueue.set(kevent, node.fd, LibC::EVFILT_WRITE, LibC::EV_DELETE, udata: node)
      size += 1
    end

    Crystal.trace :evloop, "kevent", op: "del", fd: node.fd, size: size
    @kqueue.kevent(kevents.to_slice[0, size])
  end

  private def system_sync(node : Evented::EventQueue::Node) : Nil
    if node.empty?
      system_delete(node)
      yield
    else
      kevents = uninitialized LibC::Kevent[2]
      kevent = kevents.to_unsafe
      size = 0
      registrations = Evented::EventQueue::Node::Registrations::NONE

      if node.readers?
        System::Kqueue.set(kevent, node.fd, LibC::EVFILT_READ, LibC::EV_ADD, udata: node)
        registrations |= :read
        size += 1
        kevent += 1
      elsif node.registrations.read?
        System::Kqueue.set(kevent, node.fd, LibC::EVFILT_READ, LibC::EV_DELETE, udata: node)
        size += 1
        kevent += 1
      end

      if node.writers?
        System::Kqueue.set(kevent, node.fd, LibC::EVFILT_WRITE, LibC::EV_ADD, udata: node)
        registrations |= :write
        size += 1
      elsif node.registrations.write?
        System::Kqueue.set(kevent, node.fd, LibC::EVFILT_WRITE, LibC::EV_DELETE, udata: node)
        size += 1
      end

      Crystal.trace :evloop, "kevent", op: "add", fd: node.fd, size: size, registrations: registrations.to_s
      @kqueue.kevent(kevents.to_slice[0, size])

      node.registrations = registrations
    end
  end
end
