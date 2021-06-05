require "./event_libevent"
require "./io_provider"

# :nodoc:
module Crystal::EventLoop
  {% unless flag?(:preview_mt) %}
    # Reinitializes the event loop after a fork.
    def self.after_fork : Nil
      Crystal::System.perform_io do
        io_uring do
          # TODO: This is probably broken
          Crystal::System.reset_io_uring
        end

        lib_event do |event_base|
          event_base.reinit
        end
      end
    end
  {% end %}

  # Runs the event loop.
  def self.run_once
    Crystal::System.perform_io do
      io_uring do
        Crystal::System.io_uring.process_completion_events(blocking: true)
      end

      lib_event do |event_base|
        event_base.run_once
      end
    end
  end

  # Create a new resume event for a fiber.
  def self.create_resume_event(fiber : Fiber) : Crystal::Event
    Crystal::System.perform_io_event do
      io_uring do
        Crystal::IoUringEvent.new(:resume, 0) do |res|
          Crystal::Scheduler.enqueue fiber
        end
      end

      lib_event do |event_base|
        event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
          Crystal::Scheduler.enqueue data.as(Fiber)
        end
      end
    end
  end

  # Creates a timeout_event.
  def self.create_timeout_event(fiber) : Crystal::Event
    Crystal::System.perform_io_event do
      io_uring do
        Crystal::IoUringEvent.new(:timeout, 0) do |res|
          if (select_action = fiber.timeout_select_action)
            fiber.timeout_select_action = nil
            select_action.time_expired(fiber)
          else
            Crystal::Scheduler.enqueue fiber
          end
        end
      end

      lib_event do |event_base|
        event_base.new_event(-1, LibEvent2::EventFlags::None, fiber) do |s, flags, data|
          f = data.as(Fiber)
          if (select_action = f.timeout_select_action)
            f.timeout_select_action = nil
            select_action.time_expired(f)
          else
            Crystal::Scheduler.enqueue f
          end
        end
      end
    end
  end

  # Creates a write event for a file descriptor.
  def self.create_fd_write_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::System.perform_io_event do
      io_uring do
        Crystal::IoUringEvent.new(:writable_fd, io.fd) do |res|
          if res == -Errno::ECANCELED.value
            io.resume_write(timed_out: true)
          else
            io.resume_write
          end
        end
      end

      lib_event do |event_base|
        flags = LibEvent2::EventFlags::Write
        flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

        event_base.new_event(io.fd, flags, io) do |s, flags, data|
          io_ref = data.as(typeof(io))
          if flags.includes?(LibEvent2::EventFlags::Write)
            io_ref.resume_write
          elsif flags.includes?(LibEvent2::EventFlags::Timeout)
            io_ref.resume_write(timed_out: true)
          end
        end
      end
    end
  end

  # Creates a read event for a file descriptor.
  def self.create_fd_read_event(io : IO::Evented, edge_triggered : Bool = false) : Crystal::Event
    Crystal::System.perform_io_event do
      io_uring do
        Crystal::IoUringEvent.new(:readable_fd, io.fd) do |res|
          if res == -Errno::ECANCELED.value
            io.resume_read(timed_out: true)
          else
            io.resume_read
          end
        end
      end

      lib_event do |event_base|
        flags = LibEvent2::EventFlags::Read
        flags |= LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET if edge_triggered

        event_base.new_event(io.fd, flags, io) do |s, flags, data|
          io_ref = data.as(typeof(io))
          if flags.includes?(LibEvent2::EventFlags::Read)
            io_ref.resume_read
          elsif flags.includes?(LibEvent2::EventFlags::Timeout)
            io_ref.resume_read(timed_out: true)
          end
        end
      end
    end
  end
end
