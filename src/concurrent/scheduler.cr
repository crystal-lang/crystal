require "event"

class Scheduler
  @@runnables = [] of Fiber
  @@eb = Event::Base.new
  @@loop_fiber = Fiber.new { @@eb.run_loop }

  def self.reschedule
    if runnable = @@runnables.pop?
      runnable.resume
    else
      @@loop_fiber.resume
    end
  end

  def self.sleep(time)
    @@eb.add_timer_event time, LibEvent2::Callback.new do |s, flags, data|
      fiber = data as Fiber
      fiber.resume
    end, Fiber.current as Void*
  end

  def self.create_fd_events(io : FileDescriptorIO)
    flags = LibEvent2::EventFlags::Read | LibEvent2::EventFlags::Write | LibEvent2::EventFlags::Persist | LibEvent2::EventFlags::ET
    event = LibEvent2.event_new(@@eb, io.fd, flags, LibEvent2::Callback.new do |s, flags, data|
      fd_io = data as FileDescriptorIO
      if flags.includes?(LibEvent2::EventFlags::Read)
        fd_io.resume_read
      elsif flags.includes?(LibEvent2::EventFlags::Write)
        fd_io.resume_write
      end
    end, io as Void*)

    LibEvent2.event_add(event, nil)
    event
  end

  def self.destroy_fd_events(event)
    LibEvent2.event_free(event)
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
