require "crystal/pointer_pairing_heap"

# Information about the event that a `Fiber` is waiting on.
#
# The event can be waiting for `IO` with or without a timeout, or be a timed
# event such as sleep or a select timeout (without IO).
#
# The events can be registered in `Timers` and/or `Waiter` depending on their
# type.
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

  # The IO::FileDescriptor or Socket isnatnce when processing an IO event.
  # Nil for timed events (sleep, select timeout).
  @io : IO?

  # The absolute time, against the monotonic clock, at which a timed event shall
  # trigger. Nil for IO events without a timeout.
  getter! wake_at : Time::Instant

  # True if an IO event has timed out (i.e. we're past `#wake_at`).
  getter? timed_out : Bool = false

  property timeout_select_action : Channel::TimeoutAction?

  # The event can be added to the `Timers` list.
  include PointerPairingHeap::Node

  def initialize(@type : Type, @fiber, @io = nil, timeout : Time::Span? = nil)
    if timeout
      now = Crystal::System::Time.instant
      @wake_at = now + timeout
    end
  end

  def __poll_descriptor(&) : Nil
    {% begin %}
      # manual devirtualization of IO+ into concrete types
      case io = @io
      when IO::FileDescriptor
        io.__poll_descriptor { |pd| yield pd }
      {% if @top_level.has_constant?(:Socket) %}
      when ::Socket
        io.__poll_descriptor { |pd| yield pd }
      {% end %}
      else
        raise "BUG: expected IO::FileDescriptor or Socket but got #{io.class.name}"
      end
    {% end %}
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
