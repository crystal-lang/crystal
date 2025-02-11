require "crystal/pointer_linked_list"
require "crystal/pointer_pairing_heap"

# Information about the event that a `Fiber` is waiting on.
#
# The event can be waiting for `IO` with or without a timeout, or be a timed
# event such as sleep or a select timeout (without IO).
#
# The events can be found in different queues, for example `Timers` and/or
# `Waiters` depending on their type.
struct Crystal::EventLoop::Polling::Event
  enum Type
    IoRead
    IoWrite
    Sleep
    SelectTimeout
  end

  getter type : Type

  # The `Fiber` that is waiting on the event and that the `EventLoop` shall
  # resume.
  getter fiber : Fiber

  # Arena index to access the associated `PollDescriptor` when processing an IO
  # event. Nil for timed events (sleep, select timeout).
  getter! index : Arena::Index?

  # The absolute time, against the monotonic clock, at which a timed event shall
  # trigger. Nil for IO events without a timeout.
  getter! wake_at : Time::Span

  # True if an IO event has timed out (i.e. we're past `#wake_at`).
  getter? timed_out : Bool = false

  # The event can be added to `Waiters` lists.
  include PointerLinkedList::Node

  # The event can be added to the `Timers` list.
  include PointerPairingHeap::Node

  def initialize(@type : Type, @fiber, @index = nil, timeout : Time::Span? = nil)
    if timeout
      seconds, nanoseconds = System::Time.monotonic
      now = Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
      @wake_at = now + timeout
    end
  end

  # Mark the IO event as timed out.
  def timed_out! : Bool
    @timed_out = true
  end

  # Manually set the absolute time (against the monotonic clock). This is meant
  # for `FiberEvent` to set and cancel its inner sleep or select timeout; these
  # objects are allocated once per `Fiber`.
  #
  # NOTE: musn't be changed after registering the event into `Timers`!
  def wake_at=(@wake_at)
  end

  def heap_compare(other : Pointer(self)) : Bool
    wake_at < other.value.wake_at
  end
end
