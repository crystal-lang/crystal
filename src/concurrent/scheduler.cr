class Scheduler
  @@runnables = [] of Fiber

  @@loop_fiber = Fiber.new do
    LibUV.prepare_init(UV::Loop::DEFAULT, out prepare)
    LibUV.prepare_start(pointerof(prepare), ->(p) {
      while runnable = @@runnables.pop?
        runnable.resume
      end
    })
    UV::Loop::DEFAULT.run
  end

  def self.reschedule
    if runnable = @@runnables.pop?
      runnable.resume
    else
      @@loop_fiber.resume
    end
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
