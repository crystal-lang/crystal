# A single `Event` waiting on an operation (either read or write) for a fd.
# `FdLock` serializes operations in each direction. See `PollDescriptor`.
#
# Race conditions on the state handled through the ready and always ready
# variables.
#
# Thread unsafe: parallel mutations must be protected with a lock.
struct Crystal::EventLoop::Polling::Waiter
  @event = Pointer(Event).null
  @ready = false
  @always_ready = false

  def empty? : Bool
    @event.null?
  end

  # Publishes an event unless readiness was already received.
  def add(event : Pointer(Event)) : Bool
    raise "BUG: polling operation already has a waiter" unless empty?

    # Closure, error or hangup makes readiness persistent.
    return false if @always_ready

    if @ready
      @ready = false
      return false
    end

    @event = event
    true
  end

  def delete(event : Pointer(Event)) : Nil
    @event = Pointer(Event).null if @event == event
  end

  # Detaches the pending event before processing it. If its timer already owns
  # completion, preserve readiness for the next operation.
  def ready_one(& : Pointer(Event) -> Bool) : Nil
    event, @event = @event, Pointer(Event).null
    return if event && yield event

    @ready = true
  end

  # Detaches the pending event and makes readiness persistent on close, error
  # or hangup.
  def ready_all(& : Pointer(Event) ->) : Nil
    event, @event = @event, Pointer(Event).null
    @always_ready = true
    yield event if event
  end
end
