# Information related to the evloop for a fd, such as the read and write queues
# (waiting `Event`), as well as which evloop instance currently owns the fd.
#
# Thread-unsafe: parallel mutations must be protected with a lock.
struct Crystal::EventLoop::Polling::PollDescriptor
  @event_loop : Polling?
  @readers = Waiters.new
  @writers = Waiters.new

  # Makes *event_loop* the new owner of *fd*.
  # Removes *fd* from the current event loop (if any).
  def take_ownership(event_loop : EventLoop, fd : Int32, index : Arena::Index) : Nil
    current = @event_loop

    if event_loop == current
      raise "BUG: evloop already owns the poll-descriptor for fd=#{fd}"
    end

    # ensure we can't have cross enqueues after we transfer the fd, so we
    # can optimize (all enqueues are local) and we don't end up with a timer
    # from evloop A to cancel an event from evloop B (currently unsafe)
    if current && !empty?
      raise RuntimeError.new("BUG: transfering fd=#{fd} to another evloop with pending reader/writer fibers")
    end

    @event_loop = event_loop
    event_loop.system_add(fd, index)
    current.try(&.system_del(fd, closing: false))
  end

  # Removes *fd* from its owner event loop. Raises on errors.
  def remove(fd : Int32) : Nil
    current, @event_loop = @event_loop, nil
    current.try(&.system_del(fd))
  end

  # Same as `#remove` but yields on errors.
  def remove(fd : Int32, &) : Nil
    current, @event_loop = @event_loop, nil
    current.try(&.system_del(fd) { yield })
  end

  # Returns true when there is at least one reader or writer. Returns false
  # otherwise.
  def empty? : Bool
    @readers.@list.empty? && @writers.@list.empty?
  end
end
