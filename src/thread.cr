require "c/pthread"
require "./thread/*"

# :nodoc:
class Thread
  # Don't use this class, it is used internally by the event scheduler.
  # Use spawn and channels instead.

  # all thread objects, so the GC can see them (it may not scan thread locals)
  @@threads = Set(Thread).new

  @th : LibC::PthreadT
  @exception : Exception?
  @detached = false

  property current_fiber

  # Starts a new system thread.
  def initialize(&@func : ->)
    @current_fiber = uninitialized Fiber
    @th = uninitialized LibC::PthreadT

    ret = GC.pthread_create(pointerof(@th), Pointer(LibC::PthreadAttrT).null, ->(data : Void*) {
      (data.as(Thread)).start
      Pointer(Void).null
    }, self.as(Void*))

    if ret == 0
      @@threads << self
    else
      raise Errno.new("pthread_create")
    end
  end

  # Used once to initialize the thread object representing the main thread of
  # the process (that already exists).
  def initialize
    @current_fiber = uninitialized Fiber
    @func = ->{}
    @th = LibC.pthread_self
    @@threads << self
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

    @@current_key = begin
      ret = LibC.pthread_key_create(out current_key, nil)
      raise Errno.new("pthread_key_create") unless ret == 0
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
      raise Errno.new("pthread_setspecific") unless ret == 0
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

  protected def start
    Thread.current = self
    begin
      @func.call
    rescue ex
      @exception = ex
    ensure
      @@threads.delete(self)
    end
  end
end
