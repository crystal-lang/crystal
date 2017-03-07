# :nodoc:
class RunnableQueue
  # for debugging purposes
  property name : String

  @runnables = Deque(Fiber).new
  @runnables_lock = SpinLock.new

  def initialize(@name)
  end

  def enqueue(fiber : Fiber)
    @runnables_lock.synchronize do
      # FIXME: this can trigger a GC collect
      @runnables << fiber
    end
  end

  def enqueue(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize do
      # FIXME: this can trigger a GC collect
      @runnables.concat fibers
    end
  end

  def enqueue_stolen(fibers : Enumerable(Fiber))
    @runnables_lock.synchronize do
      # FIXME: this can trigger a GC collect
      @runnables.concat fibers
    end
  end

  def steal
    @runnables_lock.synchronize do
      steal_size = @runnables.size == 1 ? 1 : @runnables.size / 2
      # FIXME: this can trigger a GC collect
      steal_size.times.map do
        @runnables.shift
      end.to_a
    end
  end

  def size
    @runnables_lock.synchronize do
      @runnables.size
    end
  end

  def shift?
    @runnables_lock.synchronize do
      @runnables.shift?
    end
  end

  {% if flag?(:concurrency_debug) %}
    def dump_scheduler
      @runnables_lock.synchronize do
        @runnables.each do |fiber|
          LibC.printf " - fiber %p %s\n", fiber.object_id, fiber.name!
        end
      end
    end
  {% end %}
end
