require "c/ioapiset"
require "crystal/system/print_error"

# :nodoc:
abstract class Crystal::EventLoop
  def self.create
    Crystal::Iocp::EventLoop.new
  end
end

# :nodoc:
class Crystal::Iocp::EventLoop < Crystal::EventLoop
  # This is a list of resume and timeout events managed outside of IOCP.
  @queue = Deque(Crystal::Iocp::Event).new

  @lock = Crystal::SpinLock.new
  @interrupted = Atomic(Bool).new(false)
  @blocked_thread = Atomic(Thread?).new(nil)

  # Returns the base IO Completion Port
  getter iocp : LibC::HANDLE do
    create_completion_port(LibC::INVALID_HANDLE_VALUE, nil)
  end

  def create_completion_port(handle : LibC::HANDLE, parent : LibC::HANDLE? = iocp)
    iocp = LibC.CreateIoCompletionPort(handle, parent, nil, 0)
    if iocp.null?
      raise IO::Error.from_winerror("CreateIoCompletionPort")
    end
    if parent
      # all overlapped operations may finish synchronously, in which case we do
      # not reschedule the running fiber; the following call tells Win32 not to
      # queue an I/O completion packet to the associated IOCP as well, as this
      # would be done by default
      if LibC.SetFileCompletionNotificationModes(handle, LibC::FILE_SKIP_COMPLETION_PORT_ON_SUCCESS) == 0
        raise IO::Error.from_winerror("SetFileCompletionNotificationModes")
      end
    end
    iocp
  end

  # Runs the event loop and enqueues the fiber for the next upcoming event or
  # completion.
  def run(blocking : Bool) : Bool
    # Pull the next upcoming event from the event queue. This determines the
    # timeout for waiting on the completion port.
    # OPTIMIZE: Implement @queue as a priority queue in order to avoid this
    # explicit search for the lowest value and dequeue more efficient.
    next_event = @queue.min_by?(&.wake_at)

    # no registered events: nothing to wait for
    return false unless next_event

    now = Time.monotonic

    if next_event.wake_at > now
      # There is no event ready to wake. We wait for completions until the next
      # event wake time, unless nonblocking or already interrupted (timeout
      # immediately).
      if blocking
        @lock.sync do
          if @interrupted.get(:acquire)
            blocking = false
          else
            # memorize the blocked thread (so we can alert it)
            @blocked_thread.set(Thread.current, :release)
          end
        end
      end

      wait_time = blocking ? (next_event.wake_at - now).total_milliseconds : 0
      timed_out = IO::Overlapped.wait_queued_completions(wait_time, alertable: blocking) do |fiber|
        # This block may run multiple times. Every single fiber gets enqueued.
        fiber.enqueue
      end

      @blocked_thread.set(nil, :release)
      @interrupted.set(false, :release)

      # The wait for completion enqueued events.
      return true unless timed_out

      # Wait for completion timed out but it may have been interrupted or we ask
      # for immediate timeout (nonblocking), so we check for the next event
      # readyness again:
      return false if next_event.wake_at > Time.monotonic
    end

    # next_event gets activated because its wake time is passed, either from the
    # start or because completion wait has timed out.

    dequeue next_event

    fiber = next_event.fiber

    # If the waiting fiber was already shut down in the mean time, we can just
    # abandon here. There's no need to go for the next event because the scheduler
    # will just try again.
    # OPTIMIZE: It might still be worth considering to start over from the top
    # or call recursively, in order to ensure at least one fiber get enqueued.
    # This would avoid the scheduler needing to looking at runnable again just
    # to notice it's still empty. The lock involved there should typically be
    # uncontested though, so it's probably not a big deal.
    return false if fiber.dead?

    # A timeout event needs special handling because it does not necessarily
    # means to resume the fiber directly, in case a different select branch
    # was already activated.
    if next_event.timeout? && (select_action = fiber.timeout_select_action)
      fiber.timeout_select_action = nil
      select_action.time_expired(fiber)
    else
      fiber.enqueue
    end

    # We enqueued a fiber.
    true
  end

  def interrupt : Nil
    thread = nil

    @lock.sync do
      @interrupted.set(true)
      thread = @blocked_thread.swap(nil, :acquire)
    end
    return unless thread

    # alert the thread to interrupt GetQueuedCompletionStatusEx
    LibC.QueueUserAPC(->(ptr : LibC::ULONG_PTR) {}, thread, LibC::ULONG_PTR.new(0))
  end

  def enqueue(event : Crystal::Iocp::Event)
    unless @queue.includes?(event)
      @queue << event
    end
  end

  def dequeue(event : Crystal::Iocp::Event)
    @queue.delete(event)
  end

  # Create a new resume event for a fiber.
  def create_resume_event(fiber : Fiber) : Crystal::EventLoop::Event
    Crystal::Iocp::Event.new(fiber)
  end

  def create_timeout_event(fiber) : Crystal::EventLoop::Event
    Crystal::Iocp::Event.new(fiber, timeout: true)
  end
end

class Crystal::Iocp::Event
  include Crystal::EventLoop::Event

  getter fiber
  getter wake_at
  getter? timeout

  def initialize(@fiber : Fiber, @wake_at = Time.monotonic, *, @timeout = false)
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.current.dequeue(self)
  end

  def delete
    free
  end

  def add(timeout : Time::Span?) : Nil
    @wake_at = timeout ? Time.monotonic + timeout : Time.monotonic
    Crystal::EventLoop.current.enqueue(self)
  end
end
