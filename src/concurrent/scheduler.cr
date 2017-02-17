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

  @@stamp = Atomic(Int32).new(0)

  def self.print_state
    @@all_mutex.synchronize do
      thread_log "schedulers: %d, sleeping: %d, spinning: %d, wake: %d\n", @@all.size, @@sleeping.get, @@spinning.get, @@wake.get
    end
  end

  def initialize(@own_event_loop = false)
    @runnables = Deque(Fiber).new
    @runnables_lock = SpinLock.new
    @thread = LibC.pthread_self.address
    @victim = 0

    unless @own_event_loop
      @reschedule_fiber = Fiber.current
    end
    @@all_mutex.synchronize do
      @@all << self
    end
  end

  def self.start
    thread_log "Scheduler start"
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
      thread_log "Scheduler #{self} waiting (runnables: %d)", @runnables.size
      # LibC.printf "%ld Going to sleep\n", LibC.pthread_self

      if @@wake.get != 0
        @@wake.add(-1)
      else
        @@wait_cv.wait(@@wait_mutex)
      end
      # LibC.printf "%ld Waking up\n", LibC.pthread_self
      thread_log "Scheduler #{self} waking up"
      @@sleeping.add(-1)
    end
  end

  def reschedule(is_reschedule_fiber = false)
    while true
      if runnable = @runnables_lock.synchronize { @runnables.shift? }
        thread_log "Reschedule #{self}: Found in queue '%s'", runnable.name!
        runnable.resume
        break
      elsif reschedule_fiber = @reschedule_fiber
        if is_reschedule_fiber
          thread_log "Reschedule #{self}: Spinning"
          @@spinning.add(1)
          could_steal = spin
          unless could_steal
            # ...
            @@sleeping.add(1)
            wait
          end
        else
          thread_log "Reschedule #{self}: Switching to rescheduling fiber %ld", reschedule_fiber.object_id
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
    while !could_steal
      begin_stamp = @@stamp.get
      scheduler_count = @@all.size
      scheduler_count.times do
        sched = choose_other_sched
        if (stolen = sched.steal) && stolen.size > 0
          thread_log "Stole #{stolen.size} runnables (#{stolen.map(&.name!).join(", ")}) from #{sched}"
          enqueue_stolen stolen
          could_steal = true
          break
        end
      end

      @@spinning.add(-1)
      if could_steal || begin_stamp == @@stamp.get
        break
      end
      @@spinning.add(1)
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
    thread_log "Enqueue '#{fiber.name}'"
    @runnables_lock.synchronize { @runnables << fiber }
    ensure_workers_available
  end

  def enqueue(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize { @runnables.concat fibers }
    ensure_workers_available
  end

  protected def enqueue_stolen(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize { @runnables.concat fibers }
  end

  private def ensure_workers_available
    @@stamp.add(1)

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

    # FIXME: race condition: this may result in more than 8 worker threads
    # FIXME: make the number of threads CPU/arch dependent (configurable?)
    # FIXME: this access to @@all is not synchronized
    if @@all.size < 8
      @@spinning.add(1)
      Thread.new do
        Fiber.current.name = "scheduler"
        Scheduler.start
      end
    end

    # ...
  end

  private def choose_other_sched
    @@all_mutex.synchronize do
      loop do
        @victim += 1
        sched = @@all[@victim.remainder(@@all.size)]
        break sched unless sched == self && @@all.size > 1
      end
    end
  end
end
