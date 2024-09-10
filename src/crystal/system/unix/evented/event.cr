# Information about the event that a `Fiber` is waiting on.
#
# The event can be waiting for `IO` with or without a timeout, or be a timed
# event such as sleep or a select timeout.
#
# The events can be found in different queues, for example `Timers` and/or
# `Waiters` depending on their type.
struct Crystal::Evented::Event
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

  # Arena index to access the associated `PollDescriptor` when processing the
  # event.
  getter! gen_index : Int64?

  # The absolute time (against the monotonic clock) at which a timed event shall
  # trigger. Can be nil for IO events without a timeout.
  getter! wake_at : Time::Span

  # True if an IO event has timed out (we're past `#wake_at`).
  getter? timed_out : Bool = false

  # The event can be added into
  include PointerLinkedList::Node

  def initialize(@type : Type, @fiber, @gen_index = nil, timeout : Time::Span? = nil)
    @wake_at = Time.monotonic + timeout if timeout
  end

  # Mark the IO event as timed out.
  def timed_out! : Bool
    @timed_out = true
  end

  # Manually set the absolute time (against the monotonic clock). This is meant
  # for `FiberEvent` to set and cancel its inner sleep or select timeout
  # (allocated once per `Fiber`).
  #
  # NOTE: musn't be changed after registering the event into timers!
  def wake_at=(@wake_at)
  end
end
