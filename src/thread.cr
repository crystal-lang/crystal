require "c/pthread"
require "c/sched"
require "./thread/*"

# :nodoc:
class Thread
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  @@threads = uninitialized Thread::LinkedList(Thread)

  {% if flag?(:mt_debug) %}
    @@color_counter = uninitialized Atomic(Int32)
    @color = 0

    def self.log(action, scheduler = nil, fiber = nil)
      thread = Thread.current
      current.log(action, thread, scheduler || thread.scheduler, fiber)
    end

    def log(action, thread, scheduler, fiber = nil)
      if fiber
        LibC.dprintf(2, "\033[%dmthread=%lx %20s scheduler=%p fiber=%p [%s]\033[0m\n",
                     @color, thread.to_unsafe, action, scheduler.as(Void*),
                     fiber.as(Void*), fiber.name.try(&.to_unsafe))
      else
        LibC.dprintf(2, "\033[%dmthread=%lx %20s scheduler=%p\033[0m\n",
                     @color, thread.to_unsafe, action, scheduler.as(Void*))
      end
    end
  {% else %}
    def self.log(action, scheduler = nil, fiber = nil)
    end
  {% end %}

  @th : LibC::PthreadT
  @exception : Exception?
  @detached = false
  @main_fiber : Fiber?

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  def self.init
    @@threads = Thread::LinkedList(Thread).new

    {% if flag?(:mt_debug) %}
      @@color_counter = Atomic(Int32).new(32)
    {% end %}

    {% if flag?(:android) || flag?(:openbsd) %}
      @@current_key = begin
        ret = LibC.pthread_key_create(out current_key, nil)
        raise Errno.new("pthread_key_create", ret) unless ret == 0
        current_key
      end
    {% end %}

    Thread.current = Thread.new
  end

  def self.unsafe_each
    @@threads.unsafe_each { |thread| yield thread }
  end

  # Starts a new system thread.
  def initialize(&@func : ->)
    @th = uninitialized LibC::PthreadT

    {% if flag?(:mt_debug) %}
      @color = @@color_counter.add(1)
    {% end %}

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
    @main_fiber = Fiber.new(stack_address)

    {% if flag?(:mt_debug) %}
      @color = @@color_counter.add(1)
    {% end %}

    @@threads.push(self)
  end

  def finalize
    GC.pthread_detach(@th) unless @detached
  end

  # Suspends the current thread until this thread terminates.
  def join
    GC.pthread_join(@th)
    @detached = true

    if exception = @exception
      raise exception
    end
  end

  {% if flag?(:android) || flag?(:openbsd) %}
    # no thread local storage (TLS) for OpenBSD or Android,
    # we use pthread's specific storage (TSS) instead:
    @@current_key : LibC::PthreadKeyT

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

  # Yields CPU time to another thread.
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
    @main_fiber = fiber = Fiber.new(stack_address)

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
      Fiber.inactive(fiber)
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
          stack.ss_sp - stack.ss_size + sysconf(LibC::SC_PAGESIZE)
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
