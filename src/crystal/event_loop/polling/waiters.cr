# A FIFO queue of `Event` waiting on the same operation (either read or write)
# for a fd. See `PollDescriptor`.
#
# Race conditions on the state of the waiting list are handled through the ready
# always ready variables.
#
# Thread unsafe: parallel mutations must be protected with a lock.
struct Crystal::EventLoop::Polling::Waiters
  @list = PointerLinkedList(Event).new
  @ready = false
  @always_ready = false

  # Adds an event to the waiting list. May return false immediately if another
  # thread marked the list as ready in parallel, returns true otherwise.
  def add(event : Pointer(Event)) : Bool
    if @always_ready
      # another thread closed the fd or we received a fd error or hup event:
      # the fd will never block again
      return false
    end

    if @ready
      # another thread readied the fd before the current thread got to add
      # the event: don't block and resets @ready for the next loop
      @ready = false
      return false
    end

    @list.push(event)
    true
  end

  def delete(event : Pointer(Event)) : Nil
    @list.delete(event) if event.value.next
  end

  # Removes one pending event or marks the list as ready when there are no
  # pending events (we got notified of readiness before a thread enqueued).
  def ready_one(& : Pointer(Event) -> Bool) : Nil
    # loop until the block succesfully processes an event (it may have to
    # dequeue the timeout from timers)
    loop do
      if event = @list.shift?
        break if yield event
      else
        # no event queued but another thread may be waiting for the lock to
        # add an event: set as ready to resolve the race condition
        @ready = true
        return
      end
    end
  end

  # Dequeues all pending events and marks the list as always ready. This must be
  # called when a fd is closed or an error or hup event occurred.
  def ready_all(& : Pointer(Event) ->) : Nil
    @list.consume_each { |event| yield event }
    @always_ready = true
  end
end
