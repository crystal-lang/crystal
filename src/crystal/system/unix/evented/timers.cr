# List of `Event` ordered by `Event#wake_at` ascending. Optimized for fast
# dequeue and determining when is the next timer event.
#
# Thread unsafe: parallel accesses much be protected.
#
# NOTE: this is a struct because it only wraps a const pointer to a deque
# allocated in the heap
#
# OPTIMIZE: consider a skiplist for quicker lookups + avoid memmove on `#add`
# and `#delete`.
struct Crystal::Evented::Timers
  def initialize
    @list = Deque(Evented::Event*).new
  end

  def empty? : Bool
    @list.empty?
  end

  # Returns the time at which the next timer is supposed to run.
  def next_ready? : Time::Span?
    @list.first?.try(&.value.wake_at)
  end

  # Dequeues and yields each ready timer (their `#wake_at` is lower than
  # `Time.monotonic`) from the oldest to the most recent (i.e. time ascending).
  def dequeue_ready(&) : Nil
    return if @list.empty?

    now = Time.monotonic
    n = 0

    @list.each do |event|
      break if event.value.wake_at > now
      yield event
      n += 1
    end

    # OPTIMIZE: consume the n entries at once
    n.times { @list.shift }
  end

  # Add a new timer into the list. Returns true if it is the next ready timer.
  def add(event : Evented::Event*) : Bool
    if @list.empty?
      @list << event
      true
    elsif index = lookup(event.value.wake_at)
      @list.insert(index, event)
      index == 0
    else
      @list.push(event)
      false
    end
  end

  private def lookup(wake_at)
    @list.each_with_index do |event, index|
      return index if event.value.wake_at >= wake_at
    end
  end

  # Removes a timer from the list. Returns true if it was the next ready timer.
  def delete(event : Evented::Event*) : Bool
    if index = @list.index(event)
      @list.delete_at(index)
      index == 0
    else
      false
    end
  end
end
