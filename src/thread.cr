require "c/pthread"
require "c/sched"
require "./thread/*"

# :nodoc:
class Thread
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  @@threads = Thread::LinkedList(Thread).new

  @th : LibC::PthreadT
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

  # Starts a new system thread.
  def initialize(&@func : ->)
    @th = uninitialized LibC::PthreadT

    ret = GC.pthread_create(pointerof(@th), Pointer(LibC::PthreadAttrT).null, ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))

    if ret == 0
      @@threads.push(self)
    else
      raise Errno.new("pthread_create", ret)
    end
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @func = ->{}
    @th = LibC.pthread_self
    @main_fiber = Fiber.new(stack_address, self)

    @@threads.push(self)
  end

  private def detach
    if @detached.compare_and_set(0, 1).last
      yield
    end
  end

  # Suspends the current thread until this thread terminates.
  def join
    detach { GC.pthread_join(@th) }

    if exception = @exception
      raise exception
    end
  end

  {% if flag?(:android) || flag?(:openbsd) %}
    # no thread local storage (TLS) for OpenBSD or Android,
    # we use pthread's specific storage (TSS) instead:
    @@current_key : LibC::PthreadKeyT

    @@current_key = begin
      ret = LibC.pthread_key_create(out current_key, nil)
      raise Errno.new("pthread_key_create", ret) unless ret == 0
      current_key
    end

    # Returns the Thread object associated to the running system thread.
    def self.current : Thread
      if ptr = LibC.pthread_getspecific(@@current_key)
        ptr.as(Thread)
      else
        raise "BUG: Thread.current returned NULL"
      end
    end

    # Associates the Thread object to the running system thread.
    protected def self.current=(thread : Thread) : Thread
      ret = LibC.pthread_setspecific(@@current_key, thread.as(Void*))
      raise Errno.new("pthread_setspecific", ret) unless ret == 0
      thread
    end
  {% else %}
    @[ThreadLocal]
    @@current : Thread?

    # Returns the Thread object associated to the running system thread.
    def self.current : Thread
      @@current || raise "BUG: Thread.current returned NULL"
    end

    # Associates the Thread object to the running system thread.
    protected def self.current=(@@current : Thread) : Thread
    end
  {% end %}

  # Create the thread object for the current thread (aka the main thread of the
  # process).
  #
  # TODO: consider moving to `kernel.cr` or `crystal/main.cr`
  self.current = new

  def self.yield
    ret = LibC.sched_yield
    raise Errno.new("sched_yield") unless ret == 0
  end

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
      detach { GC.pthread_detach(@th) }
    end
  end

  private def stack_address : Void*
    address = Pointer(Void).null

    {% if flag?(:darwin) %}
      # FIXME: pthread_get_stacksize_np returns bogus value on macOS X 10.9.0:
      address = LibC.pthread_get_stackaddr_np(@th) - LibC.pthread_get_stacksize_np(@th)

    {% elsif flag?(:freebsd) %}
      ret = LibC.pthread_attr_init(out attr)
      unless ret == 0
        LibC.pthread_attr_destroy(pointerof(attr))
        raise Errno.new("pthread_attr_init", ret)
      end

      if LibC.pthread_attr_get_np(@th, pointerof(attr)) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise Errno.new("pthread_attr_destroy", ret) unless ret == 0

    {% elsif flag?(:linux) %}
      if LibC.pthread_getattr_np(@th, out attr) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise Errno.new("pthread_attr_destroy", ret) unless ret == 0

    {% elsif flag?(:openbsd) %}
      ret = LibC.pthread_stackseg_np(@th, out stack)
      raise Errno.new("pthread_stackseg_np", ret) unless ret == 0

      address =
        if LibC.pthread_main_np == 1
          stack.ss_sp - stack.ss_size + LibC.sysconf(LibC::SC_PAGESIZE)
        else
          stack.ss_sp - stack.ss_size
        end
    {% end %}

    address
  end

  # :nodoc:
  def to_unsafe
    @th
  end
end
