require "c/iocp"
require "crystal/system/print_error"

module Crystal::EventLoop
  @@queue = Deque(Crystal::Event).new

  # Runs the event loop.
  def self.run_once : Nil
    unless @@queue.empty?
      next_event = @@queue.min_by { |e| e.wake_in }
      time_elapsed = (Time.monotonic - next_event.slept_at)

      unless time_elapsed > next_event.wake_in
        sleepy_time = (next_event.wake_in - time_elapsed).total_milliseconds.to_i
        io_entry = Slice.new(1, LibC::OVERLAPPED_ENTRY.new)
        
        if LibC.GetQueuedCompletionStatusEx(Thread.current.iocp, io_entry, 1, out removed, sleepy_time, false)
          if removed == 1 && io_entry.first.lpOverlapped
            next_event = io_entry.first.lpOverlapped.value.cEvent.unsafe_as(Crystal::Event)
          end
        else
          raise RuntimeError.from_winerror("Error getting i/o completion status")
        end
      end

      dequeue next_event
      Crystal::Scheduler.enqueue next_event.fiber
    else
      Crystal::System.print_error "Warning: No runnables in scheduler. Exiting program.\n"
      ::exit
    end
  end

  # Reinitializes the event loop after a fork.
  def self.after_fork : Nil
  end

  def self.enqueue(event : Crystal::Event)
    unless @@queue.includes?(event)
      @@queue << event
    end
  end

  def self.dequeue(event : Crystal::Event)
    @@queue.delete(event)
  end

  # Create a new resume event for a fiber.
  def self.create_resume_event(fiber : Fiber) : Crystal::Event
    Crystal::Event.new(fiber)
  end

  # Creates a write event for a file descriptor.
  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    # TODO Set event's wake_in to write timeout.
    Crystal::Event.new(Fiber.current)
  end

  # Creates a read event for a file descriptor.
  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    # TODO Set event's wake_in to read timeout.
    Crystal::Event.new(Fiber.current)
  end
end

struct Crystal::Event
  property slept_at : Time::Span
  property wake_in : Time::Span
  property fiber : Fiber

  def initialize(@fiber : Fiber)
    @wake_in = Time::Span::ZERO
    @slept_at = Time::Span::ZERO
  end

  # Frees the event
  def free : Nil
    Crystal::EventLoop.dequeue(self)
  end

  def add(time_span : Time::Span) : Nil
    @slept_at = Time.monotonic
    @wake_in = time_span
    Crystal::EventLoop.enqueue(self)
  end
  
  def to_unsafe
    pointerof(LibC::WSAOVERLAPPED.new(self))
  end
end
