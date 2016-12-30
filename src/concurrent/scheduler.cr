require "event"
require "thread"

class Thread
  property! scheduler : Scheduler
end

Thread.current.scheduler = Scheduler.new(true)

# :nodoc:
class Scheduler
  @runnables : Deque(Fiber)

  @@all = [] of Scheduler
  @@all_mutex = Thread::Mutex.new
  @thread : UInt64
  @reschedule_fiber : Fiber?

  @@wait_mutex = Thread::Mutex.new
  @@wait_cv = Thread::ConditionVariable.new

  @@sleeping = Atomic(Int32).new(0)
  @@spinning = Atomic(Int32).new(0)
  @@wake = Atomic(Int32).new(0)

  def self.print_state
    LibC.printf "sleeping: %d, spinning: %d, wake: %d\n", @@sleeping.get, @@spinning.get, @@wake.get
  end

  def initialize(@own_event_loop = false)
    @runnables = Deque(Fiber).new
    @runnables_lock = SpinLock.new
    @thread = LibC.pthread_self.address
    @victim = 0

    unless @own_event_loop
      @reschedule_fiber = Fiber.current
      @@all_mutex.synchronize do
        @@all << self
      end
    end
  end

  def self.start
    LibC.printf "Scheduler start\n"
    scheduler = new
    Thread.current.scheduler = scheduler
    scheduler.spin
    loop do
      scheduler.reschedule(true)
    end
  end

  def self.current
    Thread.current.scheduler
  end

  protected def wait
    @@wait_mutex.synchronize do
      # @@sleeping.add(1)
      log "Waiting (runnables: %d)", @runnables.size
      # LibC.printf "%ld Going to sleep\n", LibC.pthread_self

      if @@wake.get != 0
        @@wake.add(-1)
      else
        @@wait_cv.wait(@@wait_mutex)
      end
      # LibC.printf "%ld Waking up\n", LibC.pthread_self
      log "Received signal"
      @@sleeping.add(-1)
    end
  end

  def reschedule(is_reschedule_fiber = false)
    log "Reschedule"
    while true
      if runnable = @runnables_lock.synchronize { @runnables.shift? }
        log "Found in queue '%s'", runnable.name!
        runnable.resume
        break
      elsif reschedule_fiber = @reschedule_fiber
        if is_reschedule_fiber
          @@spinning.add(1)
          could_steal = spin
          unless could_steal
            # ...
            @@sleeping.add(1)
            wait
          end
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

  protected def spin
    could_steal = false
    100.times do
      sched = choose_other_sched
      if (stolen = sched.steal) && stolen.size > 0
        enqueue stolen
        could_steal = true
        break
      end
    end

    @@spinning.add(-1)

    sched = choose_other_sched
    if (stolen = sched.steal) && stolen.size > 0
      enqueue stolen
      could_steal = true
    end

    could_steal
  end

  protected def steal
    @runnables_lock.synchronize do
      steal_size = @runnables.size == 1 ? 1 : @runnables.size / 2
      steal_size.times.map do
        @runnables.pop
      end.to_a
    end
  end

  def enqueue(fiber : Fiber)
    log "Enqueue '#{fiber.name}'"
    @runnables_lock.synchronize { @runnables << fiber }

    if @@spinning.get != 0
      return
    end

    if @@sleeping.get != 0
      @@wait_mutex.synchronize do
        @@wake.add(1)
        @@wait_cv.signal
        return
      end
    end

    if @@all.size < 8
      @@spinning.add(1)
      Thread.new do
        Scheduler.start
      end
    end

    # ...
  end

  private def choose_other_sched
    @@all_mutex.synchronize do
      loop do
        sched = @@all[@victim.remainder(@@all.size)]
        break sched unless sched == self && @@all.size > 1
        @victim += 1
      end
    end
  end

  def enqueue(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize { @runnables.concat fibers }
  end
end
