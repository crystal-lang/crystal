require "./thread/linked_list"
{% if flag?(:win32) %}
  {% raise "thread not supported" %} 
{% else %}
  require "./thread/condition_variable"
  require "./thread/thread_pthread"
{% end %}

# :nodoc:
#
# Don't use this class, it is used internally by the event scheduler.
# Use spawn and channels instead.
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
end
