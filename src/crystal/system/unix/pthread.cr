require "c/pthread"
require "c/sched"

module Crystal::System::Thread
  alias Handle = LibC::PthreadT

  def to_unsafe
    @system_handle
  end

  private def init_handle
    # NOTE: the thread may start before `pthread_create` returns, so
    # `@system_handle` must be set as soon as possible; we cannot use a separate
    # handle and assign it to `@system_handle`, which would have been too late
    ret = GC.pthread_create(
      thread: pointerof(@system_handle),
      attr: Pointer(LibC::PthreadAttrT).null,
      start: ->(data : Void*) { data.as(::Thread).start; Pointer(Void).null },
      arg: self.as(Void*),
    )

    raise RuntimeError.from_os_error("pthread_create", Errno.new(ret)) unless ret == 0
  end

  def self.current_handle : Handle
    LibC.pthread_self
  end

  def self.yield_current : Nil
    ret = LibC.sched_yield
    raise RuntimeError.from_errno("sched_yield") unless ret == 0
  end

  # no thread local storage (TLS) for OpenBSD,
  # we use pthread's specific storage (TSS) instead
  #
  # Android appears to support TLS to some degree, but executables fail with
  # an underaligned TLS segment, see https://github.com/crystal-lang/crystal/issues/13951
  {% if flag?(:openbsd) || flag?(:android) %}
    @@current_key : LibC::PthreadKeyT

    @@current_key = begin
      ret = LibC.pthread_key_create(out current_key, nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(ret)) unless ret == 0
      current_key
    end

    def self.current_thread : ::Thread
      if ptr = LibC.pthread_getspecific(@@current_key)
        ptr.as(::Thread)
      else
        # Thread#start sets `Thread.current` as soon it starts. Thus we know
        # that if `Thread.current` is not set then we are in the main thread
        self.current_thread = ::Thread.new
      end
    end

    def self.current_thread=(thread : ::Thread)
      ret = LibC.pthread_setspecific(@@current_key, thread.as(Void*))
      raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(ret)) unless ret == 0
      thread
    end
  {% else %}
    @[ThreadLocal]
    class_property current_thread : ::Thread { ::Thread.new }
  {% end %}

  private def system_join : Exception?
    ret = GC.pthread_join(@system_handle)
    RuntimeError.from_os_error("pthread_join", Errno.new(ret)) unless ret == 0
  end

  private def system_close
    GC.pthread_detach(@system_handle)
  end

  private def stack_address : Void*
    address = Pointer(Void).null

    {% if flag?(:darwin) %}
      # FIXME: pthread_get_stacksize_np returns bogus value on macOS X 10.9.0:
      address = LibC.pthread_get_stackaddr_np(@system_handle) - LibC.pthread_get_stacksize_np(@system_handle)
    {% elsif (flag?(:bsd) && !flag?(:openbsd)) || flag?(:solaris) %}
      ret = LibC.pthread_attr_init(out attr)
      unless ret == 0
        LibC.pthread_attr_destroy(pointerof(attr))
        raise RuntimeError.from_os_error("pthread_attr_init", Errno.new(ret))
      end

      if LibC.pthread_attr_get_np(@system_handle, pointerof(attr)) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise RuntimeError.from_os_error("pthread_attr_destroy", Errno.new(ret)) unless ret == 0
    {% elsif flag?(:linux) %}
      if LibC.pthread_getattr_np(@system_handle, out attr) == 0
        LibC.pthread_attr_getstack(pointerof(attr), pointerof(address), out _)
      end
      ret = LibC.pthread_attr_destroy(pointerof(attr))
      raise RuntimeError.from_os_error("pthread_attr_destroy", Errno.new(ret)) unless ret == 0
    {% elsif flag?(:openbsd) %}
      ret = LibC.pthread_stackseg_np(@system_handle, out stack)
      raise RuntimeError.from_os_error("pthread_stackseg_np", Errno.new(ret)) unless ret == 0

      address =
        if LibC.pthread_main_np == 1
          stack.ss_sp - stack.ss_size + LibC.sysconf(LibC::SC_PAGESIZE)
        else
          stack.ss_sp - stack.ss_size
        end
    {% else %}
      {% raise "No `Crystal::System::Thread#stack_address` implementation available" %}
    {% end %}

    address
  end

  # Warning: must be called from the current thread itself, because Darwin
  # doesn't allow to set the name of any thread but the current one!
  private def system_name=(name : String) : String
    {% if flag?(:darwin) %}
      LibC.pthread_setname_np(name)
    {% elsif flag?(:netbsd) %}
      LibC.pthread_setname_np(@system_handle, name, nil)
    {% elsif LibC.has_method?(:pthread_setname_np) %}
      LibC.pthread_setname_np(@system_handle, name)
    {% elsif LibC.has_method?(:pthread_set_name_np) %}
      LibC.pthread_set_name_np(@system_handle, name)
    {% else %}
      {% raise "No `Crystal::System::Thread#system_name` implementation available" %}
    {% end %}
    name
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
