{% skip_file unless flag?(:without_mt) %}

require "crystal/event_loop"
require "crystal/system/print_error"
require "fiber"
require "fiber/stack_pool"
require "crystal/system/thread"

# :nodoc:
#
# Schedulers are tied to a thread, and must only ever be accessed from within
# this thread.
#
# Only the class methods are public and safe to use. Instance methods are
# protected and must never be called directly.
class Crystal::Scheduler
  class_property! scheduler : Scheduler
  @@event_loop = EventLoop.create
  @@stack_pool = Fiber::StackPool.new

  def self.init : Nil
    @@scheduler = new(Thread.current)

    {% unless flag?(:interpreted) %}
      scheduler.spawn_stack_pool_collector
    {% end %}
  end

  def self.stack_pool : Fiber::StackPool
    @@stack_pool
  end

  def self.event_loop
    @@event_loop
  end

  def self.event_loop?
    @@event_loop
  end

  def self.enqueue(fiber : Fiber) : Nil
    Crystal.trace :sched, "enqueue", fiber: fiber do
      scheduler.enqueue(fiber)
    end
  end

  def self.enqueue(fibers : Enumerable(Fiber)) : Nil
    fibers.each do |fiber|
      enqueue(fiber)
    end
  end

  def self.reschedule : Nil
    Crystal.trace :sched, "reschedule"
    scheduler.reschedule
  end

  def self.resume(fiber : Fiber) : Nil
    scheduler.resume(fiber)
  end

  @main : Fiber
  @lock = Thread::Mutex.new

  # :nodoc:
  def initialize(@thread : Thread)
    @main = thread.main_fiber
    @runnables = Deque(Fiber).new
  end

  protected def each_scheduler(& : Scheduler ->) : Nil
  end

  protected def enqueue(fiber : Fiber) : Nil
    @lock.synchronize { @runnables << fiber }
  end

  protected def enqueue(fibers : Enumerable(Fiber)) : Nil
    @lock.synchronize { @runnables.concat fibers }
  end

  protected def resume(fiber : Fiber) : Nil
    Crystal.trace :sched, "resume", fiber: fiber
    validate_resumable(fiber)

    {% if flag?(:interpreted) %}
      # No need to change the stack bottom!
    {% else %}
      GC.set_stackbottom(fiber.@stack.bottom)
    {% end %}

    current, @thread.current_fiber = @thread.current_fiber, fiber
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))
  end

  private def validate_resumable(fiber)
    return if fiber.resumable?

    if fiber.dead?
      fatal_resume_error(fiber, "tried to resume a dead fiber")
    else
      fatal_resume_error(fiber, "can't resume a running fiber")
    end
  end

  private def fatal_resume_error(fiber, message)
    Crystal::System.print_error "\nFATAL: %s: %s\n", message, fiber.to_s
    caller.each { |line| Crystal::System.print_error "  from %s\n", line }
    exit 1
  end

  protected def reschedule : Nil
    loop do
      if runnable = @lock.synchronize { @runnables.shift? }
        resume(runnable) unless runnable == @thread.current_fiber
        break
      else
        Crystal.trace :sched, "event_loop" do
          @@event_loop.run(blocking: true)
        end
      end
    end
  end

  # Background loop to cleanup unused fiber stacks.
  def spawn_stack_pool_collector
    fiber = Fiber.new(name: "stack-pool-collector", &->@@stack_pool.collect_loop)
    enqueue(fiber)
  end
end
