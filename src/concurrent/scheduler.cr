require "event"
require "thread"

class Thread
  property! scheduler : Scheduler
end

Thread.current.scheduler = Scheduler.new(true)

# :nodoc:
class Scheduler
  @runnables : Deque(Fiber)

  @@idle = [] of Scheduler
  @@all = [] of Scheduler
  @@all_mutex = Thread::Mutex.new
  @@idle_mutex = Thread::Mutex.new
  @thread : UInt64
  @reschedule_fiber : Fiber?

  def initialize(@own_event_loop = false)
    @runnables = Deque(Fiber).new
    @thread = LibC.pthread_self.address
    @wait_mutex = Thread::Mutex.new
    @wait_cv = Thread::ConditionVariable.new
    @victim = 0

    unless @own_event_loop
      @reschedule_fiber = Fiber.current
      @@all_mutex.synchronize do
        @@all << self
      end
    end
  end

  def self.start
    scheduler = new
    Thread.current.scheduler = scheduler
    loop do
      scheduler.reschedule(true)
    end
  end

  def self.current
    Thread.current.scheduler
  end

  protected def wait
    @wait_mutex.synchronize do
      log "Waiting (runnables: %d)", @runnables.size
      @wait_cv.wait(@wait_mutex) if @runnables.empty?
      log "Received signal"
    end
  end

  def reschedule(is_reschedule_fiber = false)
    log "Reschedule"
    while true
      if runnable = @wait_mutex.synchronize { @runnables.shift? }
        log "Found in queue '%s'", runnable.name!
        runnable.resume
        break
      elsif reschedule_fiber = @reschedule_fiber
        if is_reschedule_fiber
          @@idle_mutex.synchronize do
            @@idle << self
          end
          wait
        else
          log "Switching to rescheduling fiber %ld", reschedule_fiber.object_id
          reschedule_fiber.resume
          break
        end
      else
        EventLoop.resume
        break
      end
    end
    nil
  end

  def enqueue(fiber : Fiber)
    log "Enqueue '#{fiber.name}'"
    if idle_scheduler = @@idle_mutex.synchronize { @@idle.pop? }
      log "Found idle scheduler '%ld'", idle_scheduler.@thread
      idle_scheduler.enqueue_and_notify fiber
    else
      sched = choose_other_sched
      log "Enqueue in scheduler '%ld'", sched.@thread
      sched.enqueue_and_notify fiber
    end
  end

  private def choose_other_sched
    @@all_mutex.synchronize do
      loop do
        sched = @@all[Intrinsics.read_cycle_counter.remainder(@@all.size)]
        break sched unless sched == self && @@all.size > 1
      end
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
