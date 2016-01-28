require "event"

# :nodoc:
class Scheduler
  @runnables : Deque(Fiber)

  @@idle = [] of Scheduler
  @@all = [] of Scheduler
  @@idle_mutex = Mutex.new

  def initialize(@own_event_loop = false)
    @runnables = Deque(Fiber).new
    @wait_mutex = Mutex.new
    @wait_cv = ConditionVariable.new
    @@all << self
  end

  # def self.start
  #   scheduler = new
  #   @@current = scheduler
  #   @@idle_mutex.synchronize do
  #     @@idle << scheduler
  #   end
  #   scheduler.wait
  #   scheduler.reschedule
  # end

  @[ThreadLocal]
  @@current = new(true)

  def self.current
    @@current
  end

  protected def wait
    pp @wait_mutex
    @wait_mutex.synchronize do
      @wait_cv.wait(@wait_mutex)
    end
  end

  def reschedule
    while true
      if runnable = @runnables.shift?
        runnable.resume
        break
        # elsif @own_event_loop
        #   EventLoop.resume
        #   break
      else
        @@idle_mutex.synchronize do
          @@idle << self
        end
        wait
      end
    end
    nil
  end

  def enqueue(fiber : Fiber)
    if idle_scheduler = @@idle_mutex.synchronize { @@idle.pop? }
      idle_scheduler.enqueue_and_notify fiber
    else
      @runnables << fiber
    end
  end

  def enqueue_and_notify(fiber : Fiber)
    @runnables << fiber
    @wait_mutex.synchronize do
      @wait_cv.signal
    end
  end

  def enqueue(fibers : Enumerable(Fiber))
    @runnables.concat fibers
  end
end
