require "c/sys/event"

struct Crystal::System::Kqueue
  @kq : LibC::Int

  def initialize
    @kq =
      {% if LibC.has_method?(:kqueue1) %}
        LibC.kqueue1(LibC::O_CLOEXEC)
      {% else %}
        LibC.kqueue
      {% end %}
    if @kq == -1
      function_name = {% if LibC.has_method?(:kqueue1) %} "kqueue1" {% else %} "kqueue" {% end %}
      raise RuntimeError.from_errno(function_name)
    end
  end

  # Helper to register a single event. Returns immediately.
  def kevent(ident, filter, flags, fflags = 0, data = 0, udata = nil, &) : Nil
    kevent = uninitialized LibC::Kevent
    Kqueue.set pointerof(kevent), ident, filter, flags, fflags, data, udata
    ret = LibC.kevent(@kq, pointerof(kevent), 1, nil, 0, nil)
    yield if ret == -1
  end

  # Helper to register a single event. Returns immediately.
  def kevent(ident, filter, flags, fflags = 0, data = 0, udata = nil) : Nil
    kevent(ident, filter, flags, fflags, data, udata) do
      raise RuntimeError.from_errno("kevent")
    end
  end

  # Helper to register multiple *changes*. Returns immediately.
  def kevent(changes : Slice(LibC::Kevent), &) : Nil
    ret = LibC.kevent(@kq, changes.to_unsafe, changes.size, nil, 0, nil)
    yield if ret == -1
  end

  # Waits for registered events to become active. Returns a subslice to
  # *events*.
  #
  # Timeout is relative to now; blocks indefinitely if `nil`; returns
  # immediately if zero.
  def wait(events : Slice(LibC::Kevent), timeout : ::Time::Span? = nil) : Slice(LibC::Kevent)
    if timeout
      ts = uninitialized LibC::Timespec
      ts.tv_sec = typeof(ts.tv_sec).new!(timeout.@seconds)
      ts.tv_nsec = typeof(ts.tv_nsec).new!(timeout.@nanoseconds)
      tsp = pointerof(ts)
    else
      tsp = Pointer(LibC::Timespec).null
    end

    changes = Slice(LibC::Kevent).empty
    count = 0

    loop do
      count = LibC.kevent(@kq, changes.to_unsafe, changes.size, events.to_unsafe, events.size, tsp)
      break unless count == -1

      if Errno.value == Errno::EINTR
        # retry when waiting indefinitely, return otherwise
        break if timeout
      else
        raise RuntimeError.from_errno("kevent")
      end
    end

    events[0, count.clamp(0..)]
  end

  def close : Nil
    LibC.close(@kq)
  end

  @[AlwaysInline]
  def self.set(kevent : LibC::Kevent*, ident, filter, flags, fflags = 0, data = 0, udata = nil) : Nil
    kevent.value.ident = ident
    kevent.value.filter = filter
    kevent.value.flags = flags
    kevent.value.fflags = fflags
    kevent.value.data = data
    kevent.value.udata = udata ? udata.as(Void*) : Pointer(Void).null
    {% if LibC::Kevent.has_method?(:ext) %}
      kevent.value.ext.fill(0)
    {% end %}
  end
end
