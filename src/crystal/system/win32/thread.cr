require "c/processthreadsapi"
require "c/synchapi"

class Thread
  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  protected class_getter(threads) { Thread::LinkedList(Thread).new }

  @th : LibC::HANDLE
  @exception : Exception?
  @detached = Atomic(UInt8).new(0)
  @main_fiber : Fiber?

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  def self.unsafe_each(&)
    threads.unsafe_each { |thread| yield thread }
  end

  # Starts a new system thread.
  def initialize(&@func : ->)
    @th = uninitialized LibC::HANDLE

    @th = GC.beginthreadex(
      security: Pointer(Void).null,
      stack_size: LibC::UInt.zero,
      start_address: ->(data : Void*) { data.as(Thread).start; LibC::UInt.zero },
      arglist: self.as(Void*),
      initflag: LibC::UInt.zero,
      thrdaddr: Pointer(LibC::UInt).null)
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    # `GetCurrentThread` returns a _constant_ and is only meaningful as an
    # argument to Win32 APIs; to uniquely identify it we must duplicate the handle
    @th = uninitialized LibC::HANDLE
    cur_proc = LibC.GetCurrentProcess
    LibC.DuplicateHandle(cur_proc, LibC.GetCurrentThread, cur_proc, pointerof(@th), 0, true, LibC::DUPLICATE_SAME_ACCESS)

    @func = ->{}
    @main_fiber = Fiber.new(stack_address, self)

    Thread.threads.push(self)
  end

  private def detach(&)
    if @detached.compare_and_set(0, 1).last
      yield
    end
  end

  # Suspends the current thread until this thread terminates.
  def join : Nil
    detach do
      if LibC.WaitForSingleObject(@th, LibC::INFINITE) != LibC::WAIT_OBJECT_0
        @exception ||= RuntimeError.from_winerror("WaitForSingleObject")
      end
      if LibC.CloseHandle(@th) == 0
        @exception ||= RuntimeError.from_winerror("CloseHandle")
      end
    end

    if exception = @exception
      raise exception
    end
  end

  @[ThreadLocal]
  @@current : Thread?

  # Returns the Thread object associated to the running system thread.
  def self.current : Thread
    @@current ||= new
  end

  # Associates the Thread object to the running system thread.
  protected def self.current=(@@current : Thread) : Thread
  end

  def self.yield : Nil
    LibC.SwitchToThread
  end

  # Returns the Fiber representing the thread's main stack.
  def main_fiber : Fiber
    @main_fiber.not_nil!
  end

  # :nodoc:
  def scheduler : Crystal::Scheduler
    @scheduler ||= Crystal::Scheduler.new(main_fiber)
  end

  protected def start
    Thread.threads.push(self)
    Thread.current = self
    @main_fiber = fiber = Fiber.new(stack_address, self)

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      Thread.threads.delete(self)
      Fiber.inactive(fiber)
      detach { LibC.CloseHandle(@th) }
    end
  end

  private def stack_address : Void*
    {% if LibC.has_method?("GetCurrentThreadStackLimits") %}
      LibC.GetCurrentThreadStackLimits(out low_limit, out high_limit)
      Pointer(Void).new(low_limit)
    {% else %}
      tib = LibC.NtCurrentTeb
      high_limit = tib.value.stackBase
      LibC.VirtualQuery(tib.value.stackLimit, out mbi, sizeof(LibC::MEMORY_BASIC_INFORMATION))
      low_limit = mbi.allocationBase
      low_limit
    {% end %}
  end

  # :nodoc:
  def to_unsafe
    @th
  end
end
