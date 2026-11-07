# Information related to the evloop for a fd, such as the read and write waiters
# (waiting `Event`), as well as which evloop instance currently owns the fd.
#
# Thread safety: all accesses must lock the poll descriptor.
struct Crystal::EventLoop::Polling::PollDescriptor
  @mutex = Thread::Mutex.new
  @event_loop : Polling?
  @reader = Waiter.new
  @writer = Waiter.new

  def lock(&) : Nil
    @mutex.synchronize { yield }
  end

  # Makes *event_loop* the new owner of *io* (unless already).
  # Removes *io* from the current event loop (if any).
  def take_ownership(event_loop : EventLoop, io) : Nil
    current = @event_loop
    return if event_loop == current

    # ensure we can't have cross enqueues after we transfer the io, so we
    # can optimize (all enqueues are local) and we don't end up with a timer
    # from evloop A to cancel an event from evloop B (currently unsafe)
    if current && !empty?
      raise RuntimeError.new("Can't transfer fd=#{io.fd} to another polling event loop with pending reader/writer fibers")
    end

    @event_loop = event_loop

    registered = event_loop.system_add(io)
    @reader.ready_all { } unless registered.read?
    @writer.ready_all { } unless registered.write?

    current.try(&.system_del(io, closing: false))
  end

  # Removes *io* from its owner event loop. Raises on errors.
  def remove(io) : Nil
    current, @event_loop = @event_loop, nil
    current.try(&.system_del(io))
  end

  # Same as `#remove` but yields on errors.
  def remove(io, &) : Nil
    current, @event_loop = @event_loop, nil
    current.try(&.system_del(io) { yield })
  end

  # Returns true when there are no waiters.
  def empty? : Bool
    @reader.empty? && @writer.empty?
  end
end
