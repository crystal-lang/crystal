require "event"
require "thread"

class Thread
  property! scheduler : Scheduler
end

Scheduler.start_for_main_thread

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

  {% if flag?(:concurrency_debug) %}
  def self.dump_schedulers
    @@all_mutex.synchronize do
      @@all.each do |scheduler|
        LibC.printf "Scheduler %p\n", scheduler.object_id
        scheduler.dump_scheduler
      end
    end
  end

  protected def dump_scheduler
    @runnables_lock.synchronize do
      @runnables.each do |fiber|
        LibC.printf " - fiber %p %s\n", fiber.object_id, fiber.name!
      end
    end
  end
  {% end %}

  def initialize
    @runnables = Deque(Fiber).new
    @runnables_lock = SpinLock.new
    @thread = LibC.pthread_self.address
    @victim = 0

    @@all_mutex.synchronize do
      @@all << self
    end
  end

  def self.current
    Thread.current.scheduler
  end

  def self.start_for_main_thread
    scheduler = new
    Thread.current.scheduler = scheduler

    # the main thread has a separate rescheduling fiber
    scheduler.reschedule_fiber = Fiber.new(name: "main-thread-scheduler") do
      scheduler.reschedule_loop
    end
  end

  def self.start_for_background_thread
    if @@spinning.get == 0
      # @@spinning count should be above zero under normal circumstances
      STDERR.puts "WARNING: Scheduler started with spinning count in zero. Did you start a scheduler manually?"
    end

    scheduler = new
    Thread.current.scheduler = scheduler

    # background threads use the initialization fiber for rescheduling, to keep
    # the thread running the main rescheduling loop.
    scheduler.reschedule_fiber = Fiber.current
    Fiber.current.name = "scheduler"

    # spinning should have been incremented before initializing the thread, to
    # prevent more threads than needed to be started. that's we we don't call
    # reschedule directly.
    scheduler.spin
    scheduler.reschedule_loop
  end

  def self.start_for_event_loop
    # The event loop's thread has a scheduler that allows it to enqueue ready events
    # It never executes any of these runnables, but instead leaves them there to be
    # stolen by other schedulers.
    scheduler = Scheduler.new
    Thread.current.scheduler = scheduler
  end

  protected def reschedule_loop
    loop do
      reschedule(true)
    end
  end

  protected def reschedule_fiber=(fiber)
    @reschedule_fiber = fiber
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
        thread_log "Reschedule: Found in queue '%s'", runnable.name!
        runnable.resume
        break
      elsif is_reschedule_fiber
        thread_log "Reschedule: Spinning"
        @@spinning.add(1)
        could_steal = spin
        unless could_steal
          # ...
          @@sleeping.add(1)
          wait
        end
      else
        reschedule_fiber = @reschedule_fiber.not_nil!
        thread_log "Reschedule: Switching to rescheduling fiber %ld", reschedule_fiber.object_id
        reschedule_fiber.resume
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
    thread_log "Enqueue #{fibers.map(&.name!).join(", ")}"
    @runnables_lock.synchronize { @runnables.concat fibers }
    ensure_workers_available
  end

  protected def enqueue_stolen(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize { @runnables.concat fibers }
  end

  private def ensure_workers_available
    @@stamp.add(1)

    if @@spinning.get > 0
      return
    end

    if @@sleeping.get > 0
      @@wait_mutex.synchronize do
        @@wake.add(1)
        @@wait_cv.signal
        return
      end
    end

    {% if !flag?(:single_thread) %}
      # FIXME: race condition: this may result in more than 8 worker threads
      # FIXME: make the number of threads CPU/arch dependent (configurable?)
      # FIXME: this access to @@all is not synchronized
      if @@all.size < 8
        @@spinning.add(1)
        Thread.new do
          Scheduler.start_for_background_thread
        end
      end
    {% end %}

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
