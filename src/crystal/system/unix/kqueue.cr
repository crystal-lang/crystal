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
    raise RuntimeError.from_errno("kqueue1") if @kq == -1
  end

  # Registers a single event. Returns immediately.
  def kevent(ident, filter, flags, fflags = 0, data = 0, udata = nil) : Nil
    kevent = uninitialized LibC::Kevent
    Kqueue.set pointerof(kevent), ident, filter, flags, fflags, data, udata
    ret = LibC.kevent(@kq, pointerof(kevent), 1, nil, 0, nil)
    raise RuntimeError.from_errno("kevent") if ret == -1 && Errno.value != Errno::EINTR
  end

  # Registers multiple *changes*. Returns immediately.
  def kevent(changes : Slice(LibC::Kevent)) : Nil
    ret = LibC.kevent(@kq, changes.to_unsafe, changes.size, nil, 0, nil)
    raise RuntimeError.from_errno("kevent") if ret == -1 && Errno.value != Errno::EINTR
  end

  # Registers *changes* and returns ready *events*.
  # Timeout is relative to now; blocks indefinitely if `nil`; returns
  # immediately if zero.
  def kevent(changes : Slice(LibC::Kevent), events : Slice(LibC::Kevent), timeout : ::Time::Span? = nil) : Slice(LibC::Kevent)
    if timeout
      ts = uninitialized LibC::Timespec
      ts.tv_sec = typeof(ts.tv_sec).new!(timeout.@seconds)
      ts.tv_nsec = typeof(ts.tv_nsec).new!(timeout.@nanoseconds)
      tsp = pointerof(ts)
    else
      tsp = Pointer(LibC::Timespec).null
    end
    count = LibC.kevent(@kq, changes.to_unsafe, changes.size, events.to_unsafe, events.size, tsp)
    raise RuntimeError.from_errno("kevent") if count == -1 && Errno.value != Errno::EINTR
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
