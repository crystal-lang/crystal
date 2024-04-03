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
  def run_once : Nil
    # Pull the next upcoming event from the event queue. This determines the
    # timeout for waiting on the completion port.
    # OPTIMIZE: Implement @queue as a priority queue in order to avoid this
    # explicit search for the lowest value and dequeue more efficient.
    next_event = @queue.min_by?(&.wake_at)

    unless next_event
      Crystal::System.print_error "Warning: No runnables in scheduler. Exiting program.\n"
      ::exit
    end

    now = Time.monotonic

    if next_event.wake_at > now
      wait_time = next_event.wake_at - now
      # There is no event ready to wake. So we wait for completions with a
      # timeout for the next event wake time.

      timed_out = IO::Overlapped.wait_queued_completions(wait_time.total_milliseconds) do |fiber|
        # This block may run multiple times. Every single fiber gets enqueued.
        Crystal::Scheduler.enqueue fiber
      end

      # If the wait for completion timed out we've reached the wake time and
      # continue with waking `next_event`.
      return unless timed_out
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
    return if fiber.dead?

    # A timeout event needs special handling because it does not necessarily
    # means to resume the fiber directly, in case a different select branch
    # was already activated.
    if next_event.timeout? && (select_action = fiber.timeout_select_action)
      fiber.timeout_select_action = nil
      select_action.time_expired(fiber)
    else
      Crystal::Scheduler.enqueue fiber
    end
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
    Crystal::Scheduler.event_loop.dequeue(self)
  end

  def delete
    free
  end

  def add(timeout : Time::Span?) : Nil
    @wake_at = timeout ? Time.monotonic + timeout : Time.monotonic
    Crystal::Scheduler.event_loop.enqueue(self)
  end
end
