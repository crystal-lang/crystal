require "c/pthread"
require "c/sched"

class Thread
  # all thread objects, so the GC can see them (it doesn't scan thread locals)
  protected class_getter(threads) { Thread::LinkedList(Thread).new }

  @th : LibC::PthreadT
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
    @th = uninitialized LibC::PthreadT

    ret = GC.pthread_create(pointerof(@th), Pointer(LibC::PthreadAttrT).null, ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))

    if ret != 0
      raise RuntimeError.from_os_error("pthread_create", Errno.new(ret))
    end
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @func = ->{}
    @th = LibC.pthread_self
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
    detach { GC.pthread_join(@th) }

    if exception = @exception
      raise exception
    end
  end

  {% if flag?(:openbsd) %}
    # no thread local storage (TLS) for OpenBSD,
    # we use pthread's specific storage (TSS) instead:
    @@current_key : LibC::PthreadKeyT

    @@current_key = begin
      ret = LibC.pthread_key_create(out current_key, nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(ret)) unless ret == 0
      current_key
    end

    # Returns the Thread object associated to the running system thread.
    def self.current : Thread
      if ptr = LibC.pthread_getspecific(@@current_key)
        ptr.as(Thread)
      else
        # Thread#start sets @@current as soon it starts. Thus we know
        # that if @@current is not set then we are in the main thread
        self.current = new
      end
    end

    # Associates the Thread object to the running system thread.
    protected def self.current=(thread : Thread) : Thread
      ret = LibC.pthread_setspecific(@@current_key, thread.as(Void*))
      raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(ret)) unless ret == 0
      thread
    end
  {% else %}
    @[ThreadLocal]
    @@current : Thread?

    # Returns the Thread object associated to the running system thread.
    def self.current : Thread
      # Thread#start sets @@current as soon it starts. Thus we know
      # that if @@current is not set then we are in the main thread
      @@current ||= new
    end

    # Associates the Thread object to the running system thread.
    protected def self.current=(@@current : Thread) : Thread
    end
  {% end %}

  def self.yield : Nil
    ret = LibC.sched_yield
    raise RuntimeError.from_errno("sched_yield") unless ret == 0
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
      detach { GC.pthread_detach(@th) }
    end
  end

  private def stack_address : Void*
    address = Pointer(Void).null

    {% if flag?(:darwin) %}
      # FIXME: pthread_get_stacksize_np returns bogus value on macOS X 10.9.0:
      address = LibC.pthread_get_stackaddr_np(@th) - LibC.pthread_get_stacksize_np(@th)
    {% elsif flag?(:bsd) && !flag?(:openbsd) %}
      ret = LibC.pthread_attr_init(out attr)
      unless ret == 0
        LibC.pthread_attr_destroy(pointerof(attr))
        raise RuntimeError.from_os_error("pthread_attr_init", Errno.new(ret))
      end

      if LibC.pthread_attr_get_np(@th, pointerof(attr)) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise RuntimeError.from_os_error("pthread_attr_destroy", Errno.new(ret)) unless ret == 0
    {% elsif flag?(:linux) %}
      if LibC.pthread_getattr_np(@th, out attr) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise RuntimeError.from_os_error("pthread_attr_destroy", Errno.new(ret)) unless ret == 0
    {% elsif flag?(:openbsd) %}
      ret = LibC.pthread_stackseg_np(@th, out stack)
      raise RuntimeError.from_os_error("pthread_stackseg_np", Errno.new(ret)) unless ret == 0

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

# In musl (alpine) the calls to unwind API segfaults
# when the binary is statically linked. This is because
# some symbols like `pthread_once` are defined as "weak"
# and, for some reason, not linked into the final binary.
# Adding an explicit reference to the symbol ensures it's
# included in the statically linked binary.
{% if flag?(:musl) && flag?(:static) %}
  lib LibC
    fun pthread_once(Void*, Void*)
  end

  fun __crystal_static_musl_workaround
    LibC.pthread_once(nil, nil)
  end
{% end %}
