require "event"

class Scheduler
  @@runnables = [] of Fiber
  @@eb = Event::Base.new

  def self.event_base
    @@eb
  end

  def self.reschedule
    if runnable = @@runnables.pop?
      runnable.resume
    else
      @@loop_fiber.resume
    end
  end

  @@loop_fiber = Fiber.new { @@eb.run_loop }

  def self.after_fork
    @@eb.reinit
  end

  def self.sleep(time)
    event = @@eb.new_event(-1, LibEvent2::EventFlags::None, Fiber.current) do |s, flags, data|
      fiber = data as Fiber
      fiber.resume
    end
    event.add(time)
    reschedule
    event.free
  end

  def self.create_fd_events(io : FileDescriptorIO)
    flags = LibEvent2::EventFlags::Read | LibEvent2::EventFlags::Write | LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET
    event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data as FileDescriptorIO
      if flags.includes?(LibEvent2::EventFlags::Read)
        fd_io.resume_read
      end
      if flags.includes?(LibEvent2::EventFlags::Write)
        fd_io.resume_write
      end
    end
    event.add
    event
  end

  def self.create_fd_write_event(io : FileDescriptorIO)
    flags = LibEvent2::EventFlags::Write
    event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data as FileDescriptorIO
      if flags.includes?(LibEvent2::EventFlags::Write)
        fd_io.resume_write
      end
    end
    event.add
    event
  end

  def self.create_fd_read_event(io : FileDescriptorIO)
    flags = LibEvent2::EventFlags::Read
    event = @@eb.new_event(io.fd, flags, io) do |s, flags, data|
      fd_io = data as FileDescriptorIO
      if flags.includes?(LibEvent2::EventFlags::Read)
        fd_io.resume_read
      end
    end
    event.add
    event
  end

  def self.yield
    @@runnables.unshift Fiber.current
    reschedule
  end

  def self.enqueue(fiber : Fiber)
    @@runnables << fiber
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    @@runnables.concat fibers
  end
end
