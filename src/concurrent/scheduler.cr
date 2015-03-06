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

  def self.wait_fd_read(fd)
    event = LibEvent2.event_new(@@eb, fd, LibEvent2::EventFlags::Read, LibEvent2::Callback.new do |s, flags, data|
      fiber = data as Fiber
      fiber.resume
    end, Fiber.current as Void*)
    LibEvent2.event_add(event, nil)
    reschedule
    LibEvent2.event_free(event)
  end

  def self.wait_fd_write(fd)
    event = LibEvent2.event_new(@@eb, fd, LibEvent2::EventFlags::Write, LibEvent2::Callback.new do |s, flags, data|
      fiber = data as Fiber
      fiber.resume
    end, Fiber.current as Void*)
    LibEvent2.event_add(event, nil)
    reschedule
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
