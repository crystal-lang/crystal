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
  @attr : LibC::PthreadAttrT? # Will be nil for main process thread
  @exception : Exception?
  @detached = false
  @main_fiber : Fiber?

  # :nodoc:
  property next : Thread?

  # :nodoc:
  property previous : Thread?

  # Starts a new system thread.
  def initialize(&@func : ->)
    @th = uninitialized LibC::PthreadT

    ret = LibC.pthread_attr_init(out attr)
    raise Errno.new("pthread_attr_init", ret) unless ret == 0
    @attr = attr

    ret = GC.pthread_create(pointerof(@th), pointerof(attr), ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))

    if ret == 0
      @@threads.push(self)
    else
      # Finalizer will not be called to destroy @attr, so do so here
      LibC.pthread_attr_destroy(pointerof(attr))
      raise Errno.new("pthread_create", ret)
    end
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @func = ->{}
    @th = LibC.pthread_self

    @@threads.push(self)
  end

  def process_thread?
    @attr.nil?
  end

  def finalize
    @attr.try do |attr|
      LibC.pthread_attr_destroy(pointerof(attr))
      @attr = nil
    end
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
    @main_fiber ||= Fiber.new(self)
  end

  # :nodoc:
  def scheduler
    @scheduler ||= Crystal::Scheduler.new(main_fiber)
  end

  protected def start
    Thread.current = self
    fiber = main_fiber

    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
      Fiber.inactive(fiber)
    end
  end

  # :nodoc:
  def stack : Thread::Stack
    top = Pointer(Void).null
    stack_size : LibC::SizeT = 0

    {% if flag?(:darwin) %}
      bottom = LibC.pthread_get_stackaddr_np(@th)

      if process_thread?
        # Darwin's `pthread_get_stacksize_np` has not always been reliable
        # for reporting the stack size of the main thread:
        # http://permalink.gmane.org/gmane.comp.java.openjdk.hotspot.devel/11590
        # Fall back to `getrlimit`.
        LibC.getrlimit(LibC::RLIMIT_STACK, out limit)
        stack_size = limit.rlim_cur
      else
        stack_size = LibC.pthread_get_stacksize_np(@th)
      end

      top = Pointer(Void).new(bottom.address - stack_size)
    {% elsif flag?(:freebsd) %}
      ret = LibC.pthread_attr_init(out attr)
      raise Errno.new("pthread_attr_init", ret) unless ret == 0

      begin
        ret = LibC.pthread_attr_get_np(@th, pointerof(attr))
        raise Errno.new("pthread_attr_get_np", ret) unless ret == 0

        ret = LibC.pthread_attr_getstack(pointerof(attr), pointerof(top), pointerof(stack_size))
        raise Errno.new("pthread_attr_getstack", ret) unless ret == 0
      ensure
        LibC.pthread_attr_destroy(pointerof(attr))
      end
    {% elsif flag?(:linux) %}
      ret = LibC.pthread_getattr_np(@th, out attr )
      raise Errno.new("pthread_getattr_np", ret) unless ret == 0

      begin
        ret = LibC.pthread_attr_getstack(pointerof(attr), pointerof(top), pointerof(stack_size))
        raise Errno.new("pthread_attr_getstack", ret) unless ret == 0
      ensure
        LibC.pthread_attr_destroy(pointerof(attr))
      end
    {% elsif flag?(:openbsd) %}
      ret = LibC.pthread_stackseg_np(@th, out sinfo)
      raise Errno.new("pthread_stackseg_np", ret) unless ret == 0

      top = Pointer(Void).new(sinfo.ss_sp.address - sinfo.ss_size)
      stack_size = sinfo.ss_size
    {% else %}
      {% raise "unsupported platform" %}
    {% end %}

    # Guard size is found in cached `@attr` for a non-process thread.
    # For main process thread it is effectively unknown. MacOS
    # and OpenBSD don't provide an API to discover it and on Linux
    # glibc `pthread_getattr_np` makes no attempt to determine it:
    # https://code.woboq.org/userspace/glibc/nptl/pthread_getattr_np.c.html
    guard_size : UInt64? = nil
    @attr.try do |attr|
      ret = LibC.pthread_attr_getguardsize(pointerof(attr), out gs)
      raise Errno.new("pthread_attr_getguardsize", ret) unless ret == 0
      guard_size = gs.to_u64
    end

    Thread::Stack.new(top, stack_size.to_u64, guard_size)
  end
end
