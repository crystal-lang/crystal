require "event"
require "thread"

# :nodoc:
class Scheduler
  @runnables : Deque(Fiber)

  @@idle = [] of Scheduler
  @@all = [] of Scheduler
  @@idle_mutex = Thread::Mutex.new
  @[ThreadLocal]
  @@current = uninitialized Scheduler
  @@current = new(true)
  @thread : UInt64

  def initialize(@own_event_loop = false)
    @runnables = Deque(Fiber).new
    @thread = LibC.pthread_self.address
    @wait_mutex = Thread::Mutex.new
    @wait_cv = Thread::ConditionVariable.new
    @reschedule_fiber = Fiber.new("reschedule #{LibC.pthread_self.address}") { loop { reschedule(true) } }
    @victim = 0
    @@all << self
  end

  def self.start
    scheduler = new
    @@current = scheduler
    @@idle_mutex.synchronize do
      @@idle << scheduler
    end
    scheduler.wait
    scheduler.reschedule
  end

  def self.current
    @@current.not_nil!
  end

  protected def wait
    @wait_mutex.synchronize do
      log "Waiting"
      @wait_cv.wait(@wait_mutex) if @runnables.empty?
      log "Received signal"
    end
  end

  def reschedule(is_reschedule_fiber = false)
    log "Reschedule"
    while true
      if runnable = @wait_mutex.synchronize { @runnables.shift? }
        log "Found in queue '#{runnable.name}'"
        runnable.resume
        break
      elsif @own_event_loop
        EventLoop.resume
        break
      else
        @@idle_mutex.synchronize do
          @@idle << self
        end
        if is_reschedule_fiber
          wait
        else
          log "Switching to rescheduling fiber %ld", @reschedule_fiber.object_id
          @reschedule_fiber.resume
          break
        end
      end
    end
    nil
  end

  def enqueue(fiber : Fiber, force = false)
    log "Enqueue '#{fiber.name}'"
    if idle_scheduler = @@idle_mutex.synchronize { @@idle.pop? }
      log "Found idle scheduler '%ld'", idle_scheduler.@thread
      idle_scheduler.enqueue_and_notify fiber
    elsif force
      # fiber.resume
      loop do
        @victim += 1
        @victim = 1 if @victim >= @@all.size
        sched = @@all[@victim]
        next if sched == self
        sched.enqueue_and_notify fiber
        break
      end
    else
      @wait_mutex.synchronize { @runnables << fiber }
    end
  end

  def enqueue_and_notify(fiber : Fiber)
    @wait_mutex.synchronize do
      @runnables << fiber
      @wait_cv.signal
    end
  end

  def enqueue(fibers : Enumerable(Fiber))
    @wait_mutex.synchronize { @runnables.concat fibers }
  end
end
