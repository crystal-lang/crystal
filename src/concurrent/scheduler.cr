require "event"
require "thread"
require "./runnable_queue"

class Thread
  property! scheduler : Scheduler

  def scheduler?
    @scheduler
  end
end

Scheduler.start_for_main_thread

# :nodoc:
class Scheduler
  @@events_queue = RunnableQueue.new("event-loop-queue")
  @@queues : Array(RunnableQueue) = [@@events_queue]
  @@queues_mutex = Thread::Mutex.new

  @reschedule_fiber : Fiber?

  @@wait_mutex = Thread::Mutex.new
  @@wait_cv = Thread::ConditionVariable.new

  @@sleeping = Atomic(Int32).new(0)
  @@spinning = Atomic(Int32).new(0)
  @@wake = Atomic(Int32).new(0)

  @@stamp = Atomic(Int32).new(0)

  @thread : UInt64

  def self.print_state
    @@queues_mutex.synchronize do
      thread_log "schedulers: %d, sleeping: %d, spinning: %d, wake: %d\n", @@queues.size, @@sleeping.get, @@spinning.get, @@wake.get
    end
  end

  {% if flag?(:concurrency_debug) %}
  def self.dump_schedulers
    @@queues_mutex.synchronize do
      @@queues.each do |queue|
        # LibC.printf "Scheduler %p\n", scheduler.object_id
        queue.dump_scheduler
      end
    end
  end
  {% end %}

  def initialize
    @q = RunnableQueue.new(name: "#{object_id}-queue")
    @thread = LibC.pthread_self.address
    @victim = 0

    @@queues_mutex.synchronize do
      @@queues << @q
    end
  end

  protected def queue
    @q
  end

  def self.enqueue(fiber : Fiber)
    thread_log "Enqueue '#{fiber.name}'"
    current.queue.enqueue(fiber)
    Scheduler.ensure_workers_available
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    thread_log "Enqueue #{fibers.map(&.name!).join(", ")}"
    current.queue.enqueue(fibers)
    Scheduler.ensure_workers_available
  end

  def self.enqueue_event(fiber : Fiber)
    thread_log "Enqueue '#{fiber.name}' (event wakeup)"
    @@events_queue.enqueue(fiber)
    Scheduler.ensure_workers_available
  end

  def self.enqueue_event(fibers : Enumerable(Fiber))
    thread_log "Enqueue #{fibers.map(&.name!).join(", ")} (event wakeup)"
    @@events_queue.enqueue(fibers)
    Scheduler.ensure_workers_available
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
      thread_log "Scheduler %p waiting (runnables: %d)", self.object_id, @q.size
      # LibC.printf "%ld Going to sleep\n", LibC.pthread_self

      if @@wake.get != 0
        @@wake.add(-1)
      else
        @@wait_cv.wait(@@wait_mutex)
      end
      # LibC.printf "%ld Waking up\n", LibC.pthread_self
      thread_log "Scheduler %p waking up", self.object_id
      @@sleeping.add(-1)
    end
  end

  def reschedule(is_reschedule_fiber = false)
    while true
      if runnable = @q.shift?
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
      scheduler_count = @@queues.size
      scheduler_count.times do
        queue = choose_other_queue
        if (stolen = queue.steal) && stolen.size > 0
          thread_log "Stole #{stolen.size} runnables (#{stolen.map(&.name!).join(", ")}) from #{queue.name}"
          @q.enqueue_stolen stolen
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

  def self.ensure_workers_available
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
      # FIXME: this access to @@queues is not synchronized
      if @@queues.size < 8 + 1 # worker thread queues + event loop's dedicated queue
        @@spinning.add(1)
        Thread.new do
          Scheduler.start_for_background_thread
        end
      end
    {% end %}

    # ...
  end

  private def choose_other_queue
    @@queues_mutex.synchronize do
      loop do
        @victim += 1
        queue = @@queues[@victim.remainder(@@queues.size)]
        break queue unless queue == @q && @@queues.size > 1
      end
    end
  end
end
