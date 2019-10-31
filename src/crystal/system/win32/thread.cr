require "c/processthreadsapi"

# TODO: Implement for multithreading.
class Thread
  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  @@threads = Thread::LinkedList(Thread).new

  @exception : Exception?
  @detached = Atomic(UInt8).new(0)
  @main_fiber : Fiber?

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  def self.unsafe_each
    @@threads.unsafe_each { |thread| yield thread }
  end

  def initialize
    @main_fiber = Fiber.new(stack_address, self)
    @@threads.push(self)
  end

  @@current : Thread? = nil

  # Associates the Thread object to the running system thread.
  protected def self.current=(@@current : Thread) : Thread
  end

  # Returns the Thread object associated to the running system thread.
  def self.current : Thread
    @@current || raise "BUG: Thread.current returned NULL"
  end

  # Create the thread object for the current thread (aka the main thread of the
  # process).
  #
  # TODO: consider moving to `kernel.cr` or `crystal/main.cr`
  self.current = new

  # Returns the Fiber representing the thread's main stack.
  def main_fiber
    @main_fiber.not_nil!
  end

  # :nodoc:
  def scheduler
    @scheduler ||= Crystal::Scheduler.new(main_fiber)
  end

  protected def start
    Thread.current = self
    @main_fiber = fiber = Fiber.new(stack_address, self)

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
      Fiber.inactive(fiber)
      detach_self
    end
  end

  private def stack_address : Void*
    LibC.GetCurrentThreadStackLimits(out low_limit, out high_limit)

    Pointer(Void).new(low_limit)
  end
end
