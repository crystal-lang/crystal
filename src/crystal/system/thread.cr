# :nodoc:
module Crystal::System::Thread
  # alias Handle

  # def self.new_handle(thread_obj : ::Thread) : Handle

  # def self.current_handle : Handle

  # def self.yield_current : Nil

  # def self.current_thread : ::Thread

  # def self.current_thread=(thread : ::Thread)

  # private def system_join : Exception?

  # private def system_close

  # private def stack_address : Void*

  # private def system_name=(String) : String
end

{% if flag?(:wasi) %}
  require "./wasi/thread"
{% elsif flag?(:unix) %}
  require "./unix/pthread"
{% elsif flag?(:win32) %}
  require "./win32/thread"
{% else %}
  {% raise "Thread not supported" %}
{% end %}

# :nodoc:
class Thread
  include Crystal::System::Thread

  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  protected class_getter(threads) { Thread::LinkedList(Thread).new }

  @system_handle : Crystal::System::Thread::Handle
  @exception : Exception?
  @detached = Atomic::Flag.new

  # Returns the Fiber representing the thread's main stack.
  getter! main_fiber : Fiber

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  getter name : String?

  def self.unsafe_each(&)
    threads.unsafe_each { |thread| yield thread }
  end

  # Creates and starts a new system thread.
  def initialize(@name : String? = nil, &@func : ->)
    @system_handle = uninitialized Crystal::System::Thread::Handle
    init_handle
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @func = ->{}
    @system_handle = Crystal::System::Thread.current_handle
    @main_fiber = Fiber.new(stack_address, self)

    Thread.threads.push(self)
  end

  private def detach(&)
    if @detached.test_and_set
      yield
    end
  end

  # Suspends the current thread until this thread terminates.
  def join : Nil
    detach do
      if ex = system_join
        @exception ||= ex
      end
    end

    if exception = @exception
      raise exception
    end
  end

  # Returns the Thread object associated to the running system thread.
  def self.current : Thread
    Crystal::System::Thread.current_thread
  end

  # Associates the Thread object to the running system thread.
  protected def self.current=(current : Thread) : Thread
    Crystal::System::Thread.current_thread = current
    current
  end

  # Yields the currently running thread.
  def self.yield : Nil
    Crystal::System::Thread.yield_current
  end

  # Changes the name of the current thread.
  def self.name=(name : String) : String
    thread = Thread.current
    thread.name = name
  end

  # :nodoc:
  getter scheduler : Crystal::Scheduler { Crystal::Scheduler.new(self) }

  protected def start
    Thread.threads.push(self)
    Thread.current = self
    @main_fiber = fiber = Fiber.new(stack_address, self)

    if name = @name
      self.system_name = name
    end

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      Thread.threads.delete(self)
      Fiber.inactive(fiber)
      detach { system_close }
    end
  end

  protected def name=(@name : String)
    self.system_name = name
  end

  # Holds the GC thread handler
  property gc_thread_handler : Void* = Pointer(Void).null
end

require "./thread_linked_list"
require "./thread_condition_variable"
