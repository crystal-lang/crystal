require "crystal/system/event_loop"
require "crystal/system/print_error"
require "./fiber_channel"
require "fiber"
require "crystal/system/thread"

# :nodoc:
#
# Schedulers are tied to a thread, and must only ever be accessed from within
# this thread.
#
# Only the class methods are public and safe to use. Instance methods are
# protected and must never be called directly.
class Crystal::Scheduler
  def self.current_fiber : Fiber
    Thread.current.scheduler.@current
  end

  def self.enqueue(fiber : Fiber) : Nil
    {% if flag?(:preview_mt) %}
      th = fiber.@current_thread.lazy_get

      if th.nil?
        th = Thread.current.scheduler.find_target_thread
      end

      if th == Thread.current
        Thread.current.scheduler.enqueue(fiber)
      else
        th.scheduler.send_fiber(fiber)
      end
    {% else %}
      Thread.current.scheduler.enqueue(fiber)
    {% end %}
  end

  def self.enqueue(fibers : Enumerable(Fiber)) : Nil
    fibers.each do |fiber|
      enqueue(fiber)
    end
  end

  def self.reschedule : Nil
    Thread.current.scheduler.reschedule
  end

  def self.resume(fiber : Fiber) : Nil
    Thread.current.scheduler.resume(fiber)
  end

  def self.sleep(time : Time::Span) : Nil
    Thread.current.scheduler.sleep(time)
  end

  def self.yield : Nil
    Thread.current.scheduler.yield
  end

  def self.yield(fiber : Fiber) : Nil
    Thread.current.scheduler.yield(fiber)
  end

  {% if flag?(:preview_mt) %}
    def self.enqueue_free_stack(stack : Void*) : Nil
      Thread.current.scheduler.enqueue_free_stack(stack)
    end
  {% end %}

  {% if flag?(:preview_mt) %}
    @fiber_channel = Crystal::FiberChannel.new
    @free_stacks = Deque(Void*).new
  {% end %}
  @lock = Crystal::SpinLock.new
  @sleeping = false

  # :nodoc:
  def initialize(@main : Fiber)
    @current = @main
    @runnables = Deque(Fiber).new
  end

  protected def enqueue(fiber : Fiber) : Nil
    @lock.sync { @runnables << fiber }
  end

  protected def enqueue(fibers : Enumerable(Fiber)) : Nil
    @lock.sync { @runnables.concat fibers }
  end

  protected def resume(fiber : Fiber) : Nil
    validate_resumable(fiber)
    {% if flag?(:preview_mt) %}
      set_current_thread(fiber)
      GC.lock_read
    {% else %}
      GC.set_stackbottom(fiber.@stack_bottom)
    {% end %}

    current, @current = @current, fiber
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))

    {% if flag?(:preview_mt) %}
      GC.unlock_read
    {% end %}
  end

  private def validate_resumable(fiber)
    return if fiber.resumable?

    if fiber.dead?
      fatal_resume_error(fiber, "tried to resume a dead fiber")
    else
      fatal_resume_error(fiber, "can't resume a running fiber")
    end
  end

  private def set_current_thread(fiber)
    fiber.@current_thread.set(Thread.current)
  end

  private def fatal_resume_error(fiber, message)
    Crystal::System.print_error "\nFATAL: #{message}: #{fiber}\n"
    {% unless flag?(:win32) %}
      # FIXME: Enable when caller is supported on win32
      caller.each { |line| Crystal::System.print_error "  from #{line}\n" }
    {% end %}

    exit 1
  end

  {% if flag?(:preview_mt) %}
    protected def enqueue_free_stack(stack)
      @free_stacks.push stack
    end

    private def release_free_stacks
      while stack = @free_stacks.shift?
        Fiber.stack_pool.release stack
      end
    end
  {% end %}

  protected def reschedule : Nil
    loop do
      if runnable = @lock.sync { @runnables.shift? }
        unless runnable == Fiber.current
          runnable.resume
        end
        break
      else
        Crystal::EventLoop.run_once
      end
    end

    {% if flag?(:preview_mt) %}
      release_free_stacks
    {% end %}
  end

  protected def sleep(time : Time::Span) : Nil
    @current.resume_event.add(time)
    reschedule
  end

  protected def yield : Nil
    sleep(0.seconds)
  end

  protected def yield(fiber : Fiber) : Nil
    @current.resume_event.add(0.seconds)
    resume(fiber)
  end

  {% if flag?(:preview_mt) %}
    @rr_target = 0

    protected def find_target_thread
      if workers = @@workers
        @rr_target += 1
        workers[@rr_target % workers.size]
      else
        Thread.current
      end
    end

    def run_loop
      loop do
        @lock.lock
        if runnable = @runnables.shift?
          @runnables << Fiber.current
          @lock.unlock
          runnable.resume
        else
          @sleeping = true
          @lock.unlock
          fiber = @fiber_channel.receive

          @lock.lock
          @sleeping = false
          @runnables << Fiber.current
          @lock.unlock
          fiber.resume
        end
      end
    end

    def send_fiber(fiber : Fiber)
      @lock.lock
      if @sleeping
        @fiber_channel.send(fiber)
      else
        @runnables << fiber
      end
      @lock.unlock
    end

    def self.init_workers
      count = worker_count
      pending = Atomic(Int32).new(count - 1)
      @@workers = Array(Thread).new(count) do |i|
        if i == 0
          worker_loop = Fiber.new(name: "Worker Loop") { Thread.current.scheduler.run_loop }
          Thread.current.scheduler.enqueue worker_loop
          Thread.current
        else
          Thread.new do
            scheduler = Thread.current.scheduler
            pending.sub(1)
            scheduler.run_loop
          end
        end
      end

      # Wait for all worker threads to be fully ready to be used
      while pending.get > 0
        Fiber.yield
      end
    end

    private def self.worker_count
      env_workers = ENV["CRYSTAL_WORKERS"]?

      if env_workers && !env_workers.empty?
        workers = env_workers.to_i?
        if !workers || workers < 1
          LibC.dprintf 2, "FATAL: Invalid value for CRYSTAL_WORKERS: #{env_workers}\n"
          exit 1
        end

        workers
      else
        # TODO: default worker count, currenlty hardcoded to 4 that seems to be something
        # that is benefitial for many scenarios without adding too much contention.
        # In the future we could use the number of cores or something associated to it.
        4
      end
    end
  {% end %}
end
