# :nodoc:
module Crystal::EventLoop::LibEvent::Evented
  @read_timed_out = Atomic(Bool).new(false)
  @write_timed_out = Atomic(Bool).new(false)

  @reader = Atomic(Fiber?).new(nil)
  @writer = Atomic(Fiber?).new(nil)

  @read_event = Atomic(Event?).new(nil)
  @write_event = Atomic(Event?).new(nil)

  # :nodoc:
  def resume_read(timed_out = false) : Nil
    @read_timed_out.set(timed_out, :relaxed)

    if reader = @reader.swap(nil, :relaxed)
      {% if !flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context) %}
        event_loop = EventLoop.current.as(LibEvent)
        event_loop.callback_enqueue(reader)
      {% else %}
        reader.enqueue
      {% end %}
    end
  end

  # :nodoc:
  def resume_write(timed_out = false) : Nil
    @write_timed_out.set(timed_out, :relaxed)

    if writer = @writer.swap(nil, :relaxed)
      {% if !flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context) %}
        event_loop = EventLoop.current.as(LibEvent)
        event_loop.callback_enqueue(writer)
      {% else %}
        writer.enqueue
      {% end %}
    end
  end

  # :nodoc:
  def evented_wait_readable(timeout = @read_timeout, *, raise_if_closed = true, &) : Nil
    @reader.set(Fiber.current, :sequentially_consistent)
    add_read_event(timeout)

    Fiber.suspend

    if @read_timed_out.swap(false, :relaxed)
      yield
    end

    check_open if raise_if_closed
  end

  private def add_read_event(timeout = @read_timeout) : Nil
    unless event = @read_event.get(:relaxed)
      event = Crystal::EventLoop.current.create_fd_read_event(self)
      @read_event.set(event, :relaxed)
    end
    event.add timeout
  end

  # :nodoc:
  def evented_wait_writable(timeout = @write_timeout, &) : Nil
    @writer.set(Fiber.current, :sequentially_consistent)
    add_write_event(timeout)

    Fiber.suspend

    if @write_timed_out.swap(false, :relaxed)
      yield
    end

    check_open
  end

  private def add_write_event(timeout = @write_timeout) : Nil
    unless event = @write_event.get(:relaxed)
      event = Crystal::EventLoop.current.create_fd_write_event(self)
      @write_event.set(event, :relaxed)
    end
    event.add timeout
  end

  # :nodoc:
  def evented_close : Nil
    @read_event.swap(nil, :relaxed).try &.free
    @write_event.swap(nil, :relaxed).try &.free
    @reader.swap(nil).try &.enqueue
    @writer.swap(nil).try &.enqueue
  end
end

module Crystal::System::FileDescriptor
  include EventLoop::LibEvent::Evented
end

module Crystal::System::Socket
  include EventLoop::LibEvent::Evented
end
