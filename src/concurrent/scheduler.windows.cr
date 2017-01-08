require "event"

# :nodoc:
class Scheduler
  @@runnables = Deque(Fiber).new
  @@timers = Hash(Fiber, LibWindows::Handle).new

  def self.reschedule
    if runnable = @@runnables.shift?
      runnable.resume
    else
      loop_fiber.resume
    end
    nil
  end

  def self.completion_port
    completion_port = @@completion_port ||= LibWindows.create_io_completion_port(LibWindows::INVALID_HANDLE_VALUE, nil, nil, 0)
    if completion_port.null?
      raise WinError.new("CreateIoCompletionPort")
    end
    completion_port
  end

  def self.attach_to_completion_port(handle, fd) : Bool
    if LibWindows.create_io_completion_port(handle, Scheduler.completion_port, fd.as(Void*), 0).null?
      # It is allowed to fail if the handle doesn't have FILE_FLAG_OVERLAPPED.
      # How to check for if the flag is set on the handle?

      # raise WinError.new("CreateIoCompletionPort")
      return false
    end
    true
  end

  def self.loop_fiber
    @@loop_fiber ||= Fiber.new do
      loop do
        bytes_transfered = 0u32
        data = Pointer(Void).null
        entry = uninitialized LibWindows::Overlapped*
        if LibWindows.get_queued_completion_status(Scheduler.completion_port, pointerof(bytes_transfered), pointerof(data), pointerof(entry), LibWindows::INFINITY)
          if entry.null?
            # It is just a fiber wanting to be resumed
            fiber = data.as(Fiber)
            if timer_handle = @@timers[fiber]?
              unless LibWindows.delete_timer_queue_timer(nil, timer_handle, nil)
                error = WinError.new "DeleteTimerQueueTimer"
                raise error if error.code != WinError::ERROR_IO_PENDING && error.code != WinError::ERROR_SUCCESS
              end
              @@timers.delete(fiber)
            end
            fiber.resume
          else
            fd = data.as(IO::FileDescriptor)
            fd.resume_overlapped entry
          end
        end
      end
    end
  end

  def self.create_resume_event(fiber)
    unless LibWindows.post_queued_completion_status(Scheduler.completion_port, 0, fiber.as(Void*), nil)
      raise WinError.new "PostQueueCompletionStatus"
    end
  end

  def self.create_sleep_event(fiber, seconds)
    LibWindows.create_timer_queue_timer(out handle, nil, ->(data, fired) {
      # this is run inside a thread from a pool managed by the system
      Scheduler.create_resume_event(data.as(Fiber))
    }, fiber.as(Void*), (seconds*1000).to_u32, 0, 0)

    @@timers[fiber] = handle
  end

  # def self.create_fd_write_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
  #   flags = LibEvent2::EventFlags::Write
  #   flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
  #   event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
  #     fd_io = data.as(IO::FileDescriptor)
  #     if flags.includes?(LibEvent2::EventFlags::Write)
  #       fd_io.resume_write
  #     elsif flags.includes?(LibEvent2::EventFlags::Timeout)
  #       fd_io.write_timed_out = true
  #       fd_io.resume_write
  #     end
  #   end
  #   event
  # end

  # def self.create_fd_read_event(io : IO::FileDescriptor, edge_triggered : Bool = false)
  #   flags = LibEvent2::EventFlags::Read
  #   flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered
  #   event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
  #     fd_io = data.as(IO::FileDescriptor)
  #     if flags.includes?(LibEvent2::EventFlags::Read)
  #       fd_io.resume_read
  #     elsif flags.includes?(LibEvent2::EventFlags::Timeout)
  #       fd_io.read_timed_out = true
  #       fd_io.resume_read
  #     end
  #   end
  #   event
  # end

  # def self.create_signal_event(signal : Signal, chan)
  #   flags = LibEvent2::EventFlags::Signal | LibEvent2::EventFlags::Persist
  #   event = @@eb.new_event(Int32.new(signal.to_i), flags, chan) do |s, flags, data|
  #     ch = data.as(Channel::Buffered(Signal))
  #     sig = Signal.new(s)
  #     ch.send sig
  #   end
  #   event.add
  #   event
  # end

  # @@dns_base : Event::DnsBase?

  # private def self.dns_base
  #   @@dns_base ||= @@eb.new_dns_base
  # end

  # def self.create_dns_request(nodename, servname, hints, data, &callback : LibEvent2::DnsGetAddrinfoCallback)
  #   dns_base.getaddrinfo(nodename, servname, hints, data, &callback)
  # end

  def self.enqueue(fiber : Fiber)
    @@runnables << fiber
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    @@runnables.concat fibers
  end
end
