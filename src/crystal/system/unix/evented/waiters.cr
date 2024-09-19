# A FIFO queue of `Event` waiting on the same operation (either read or write)
# for a fd. See `PollDescriptor`.
#
# Thread safe: mutations are protected with a lock, and race conditions are
# handled through the ready atomic.
struct Crystal::Evented::Waiters
  @ready = Atomic(Bool).new(false)
  @lock = SpinLock.new
  @list = PointerLinkedList(Event).new

  def add(event : Pointer(Event)) : Bool
    {% if flag?(:preview_mt) %}
      # check for readiness since another thread running the evloop might be
      # trying to dequeue an event while we're waiting on the lock (failure to
      # notice notice the IO is ready)
      return false if ready?

      @lock.sync do
        return false if ready?
        @list.push(event)
      end
    {% else %}
      @list.push(event)
    {% end %}

    true
  end

  def delete(event) : Nil
    @lock.sync { @list.delete(event) }
  end

  def consume_each(&) : Nil
    @lock.sync do
      @list.consume_each { |event| yield event }
    end
  end

  def ready? : Bool
    @ready.swap(false, :relaxed)
  end

  def ready(& : Pointer(Event) -> Bool) : Nil
    @lock.sync do
      {% if flag?(:preview_mt) %}
        # loop until the block succesfully processes an event (it may have to
        # dequeue the timeout from timers)
        loop do
          if event = @list.shift?
            break if yield event
          else
            # no event queued but another thread may be waiting for the lock to
            # add an event: set as ready to resolve the race condition
            @ready.set(true, :relaxed)
            return
          end
        end
      {% else %}
        if event = @list.shift?
          yield event
        end
      {% end %}
    end
  end
end
