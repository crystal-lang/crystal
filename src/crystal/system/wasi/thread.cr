class Thread
  @main_fiber : Fiber?

  def initialize
    @main_fiber = Fiber.new(stack_address, self)

    # TODO: Create thread
  end

  def initialize(&func : ->)
    initialize
  end

  def join : Nil
    raise NotImplementedError.new("Thread#join")
  end

  def self.yield : Nil
    raise NotImplementedError.new("Thread.yield")
  end

  @@current = Thread.new

  # Associates the Thread object to the running system thread.
  protected def self.current=(@@current : Thread) : Thread
  end

  # Returns the Thread object associated to the running system thread.
  def self.current : Thread
    @@current
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
    raise NotImplementedError.new("Thread#start")
  end

  private def stack_address : Void*
    # TODO: Implement
    Pointer(Void).null
  end
end
