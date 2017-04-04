require "event"
require "thread"
require "./concurrent/event_loop"

class Thread
  property! scheduler : Scheduler
end

lib LibC
  fun usleep(time : UInt32) : Void
end

# :nodoc:
class Scheduler
  class Node
    property! fiber : Fiber
    property next_node : Atomic(Node?)

    def initialize(@fiber)
      @next_node = Atomic(Node?).new(nil)
    end
  end

  WORKER_COUNT = 8

  DUMMY_NODE = Node.new(nil)

  @@head = Atomic(Node).new(DUMMY_NODE)
  @@tail = Atomic(Node).new(DUMMY_NODE)

  @@wait_mutex = Thread::Mutex.new
  @@wait_cv = Thread::ConditionVariable.new

  @@sleeping = Atomic(Int32).new(0)
  @@wake = Atomic(Int32).new(0)

  @reschedule_fiber : Fiber?
  @thread : UInt64

  def initialize
    @thread = LibC.pthread_self.address
  end

  def self.enqueue(fiber : Fiber)
    thread_log "Enqueue '#{fiber.name}'"
    internal_enqueue(fiber)
    ensure_workers_available
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    thread_log "Enqueue #{fibers.map(&.name!).join(", ")}"
    internal_enqueue(fibers)
    ensure_workers_available
  end

  def self.enqueue_event(fiber : Fiber)
    thread_log "Enqueue '#{fiber.name}' (event wakeup)"
    internal_enqueue(fiber)
    ensure_workers_available
  end

  def self.enqueue_event(fibers : Enumerable(Fiber))
    thread_log "Enqueue #{fibers.map(&.name!).join(", ")} (event wakeup)"
    internal_enqueue(fibers)
    ensure_workers_available
  end

  protected def self.internal_enqueue(fibers : Enumerable(Fiber))
    fibers.each do |fiber|
      internal_enqueue(fiber)
    end
  end

  protected def self.internal_enqueue(fiber : Fiber)
    node = Node.new(fiber)
    while true
      tail = @@tail.get
      next_node = tail.next_node.get
      if tail == @@tail.get
        if next_node.nil?
          if tail.next_node.compare_and_set(next_node, node)[1]
            break
          end
        else
          @@tail.compare_and_set(tail, next_node)
        end
      end
    end
    @@tail.compare_and_set(tail, node)
    nil
  end

  protected def self.internal_dequeue : Fiber?
    while true
      head = @@head.get
      tail = @@tail.get
      next_node = head.next_node.get
      if head == @@head.get
        if head == tail
          if next_node.nil?
            return nil
          else
            @@tail.compare_and_set(tail, next_node)
          end
        else
          if @@head.compare_and_set(head, next_node.not_nil!)[1]
            return next_node.not_nil!.fiber
          end
        end
      end
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

    (WORKER_COUNT - 1).times do
      Thread.new do
        Scheduler.start_for_worker_thread
      end
    end
  end

  protected def self.start_for_worker_thread
    scheduler = new
    Thread.current.scheduler = scheduler

    # worker threads use the initialization fiber for rescheduling, to keep
    # the thread running the main rescheduling loop.
    scheduler.reschedule_fiber = Fiber.current
    Fiber.current.name = "scheduler"

    # spinning should have been incremented before initializing the thread, to
    # prevent more threads than needed to be started. that's we we don't call
    # reschedule directly.
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
    # @@wait_mutex.synchronize do
    #   # @@sleeping.add(1)
    #   thread_log "Scheduler %p waiting", self.object_id

    #   if @@wake.get != 0
    #     @@wake.add(-1)
    #   else
    #     @@wait_cv.wait(@@wait_mutex)
    #   end
    #   thread_log "Scheduler %p waking up", self.object_id
    #   @@sleeping.add(-1)
    # end
    LibC.usleep(100)
  end

  def reschedule(is_reschedule_fiber = false)
    while true
      if runnable = Scheduler.internal_dequeue
        thread_log "Reschedule: Found in queue '%s'", runnable.name!
        runnable.resume
        break
      elsif is_reschedule_fiber
        # @@sleeping.add(1)
        wait
      else
        reschedule_fiber = @reschedule_fiber.not_nil!
        thread_log "Reschedule: Switching to rescheduling fiber %ld", reschedule_fiber.object_id
        reschedule_fiber.resume
        break
      end
    end
    nil
  end

  def self.ensure_workers_available
    # if @@sleeping.get > 0
    #   @@wait_mutex.synchronize do
    #     @@wake.add(1)
    #     @@wait_cv.signal
    #     return
    #   end
    # end

    # # ...
  end
end

Scheduler.start_for_main_thread
