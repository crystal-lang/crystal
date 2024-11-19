require "crystal/pointer_pairing_heap"

# List of `Event` ordered by `Event#wake_at` ascending. Optimized for fast
# dequeue and determining when is the next timer event.
#
# Thread unsafe: parallel accesses much be protected!
#
# NOTE: this is a struct because it only wraps a const pointer to an object
# allocated in the heap.
struct Crystal::Evented::Timers
  def initialize
    @heap = PointerPairingHeap(Evented::Event).new
  end

  def empty? : Bool
    @heap.empty?
  end

  # Returns the time of the next ready timer (if any).
  def next_ready? : Time::Span?
    @heap.first?.try(&.value.wake_at)
  end

  # Dequeues and yields each ready timer (their `#wake_at` is lower than
  # `System::Time.monotonic`) from the oldest to the most recent (i.e. time
  # ascending).
  def dequeue_ready(& : Evented::Event* -> Nil) : Nil
    seconds, nanoseconds = System::Time.monotonic
    now = Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)

    while event = @heap.first?
      break if event.value.wake_at > now
      @heap.shift?
      yield event
    end
  end

  # Add a new timer into the list. Returns true if it is the next ready timer.
  def add(event : Evented::Event*) : Bool
    @heap.add(event)
  end

  # Remove a timer from the list. Returns a tuple(dequeued, was_next_ready) of
  # booleans. The first bool tells whether the event was dequeued, in which case
  # the second one tells if it was the next ready event.
  def delete(event : Evented::Event*) : {Bool, Bool}
    @heap.delete(event)
  end
end
