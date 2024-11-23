# This file defines the functions `__crystal_once_init` and `__crystal_once` expected
# by the compiler. `__crystal_once` is called each time a constant or class variable
# has to be initialized and is its responsibility to verify the initializer is executed
# only once. `__crystal_once_init` is executed only once at the beginning of the program
# and the result is passed on each call to `__crystal_once`.

# :nodoc:
module Crystal
  # :nodoc:
  enum OnceState : Int8
    Processing    = -1
    Uninitialized =  0
    Initialized   =  1
  end

  # On Win32, `Crystal::System::FileDescriptor#@@reader_thread` spawns a new
  # thread even without the `preview_mt` flag, and the thread can also reference
  # Crystal constants, leading to race conditions, so we always enable the mutex
  # TODO: can this be improved?
  {% if flag?(:preview_mt) || flag?(:win32) %}
    # This variable is uninitialized so this variable
    # won't be initialized using `__crystal_once`.
    @@once_mutex = uninitialized Mutex

    # :nodoc:
    def self.once_mutex : Mutex
      Atomic::Ops.load(pointerof(@@once_mutex).as(Void**), :acquire, volatile: false).as(Mutex)
    end

    # :nodoc:
    def self.once_mutex=(val : Mutex) : Nil
      Atomic::Ops.store(pointerof(@@once_mutex).as(Void**), val.as(Void*), :release, volatile: false)
    end
  {% end %}
end

# :nodoc:
# This method is supposed to initialize and return the state variable used for `__crystal_once`,
# but using the `Crystal::ONCE_MUTEX` variable in combination with the @[AlwaysInline] annotation
# on `__crystal_once` allows LLVM to defer loading the once mutex to when we actually need it.
#
# Since we only need the once mutex on the first access of any const variable,
# but don't need it all the other times, this reduces the register pressure when accessing a const.
fun __crystal_once_init : Void*
  {% if flag?(:preview_mt) || flag?(:win32) %}
    Crystal.once_mutex = Mutex.new(:reentrant)
  {% end %}

  Pointer(Void).null
end

# :nodoc:
# Simply defers to `__crystal_once_exec` in the rare case we need to initialize a variable.
#
# Using `@[AlwaysInline]` allows LLVM to optimize const accesses, but since this is a `fun`,
# the function will appear in the symbol table but will never be referenced.
@[AlwaysInline]
fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*) : Void
  return if flag.as(Crystal::OnceState*).value.initialized?
  __crystal_once_exec(flag, initializer)
end

# :nodoc:
# Using @[NoInline] so llvm optimizes for the hot path (var already initialized).
@[NoInline]
fun __crystal_once_exec(flag : Bool*, initializer : Void*) : Void
  flag = flag.as(Crystal::OnceState*)

  {% if flag?(:preview_mt) || flag?(:win32) %}
    state = Crystal.once_mutex
    state.lock
  {% end %}

  begin
    flag_value = Atomic::Ops.load(flag, :acquire, volatile: false)
    return if flag_value.initialized?

    raise "Recursion while initializing class variables and/or constants" if flag_value.processing?

    Atomic::Ops.store(flag, :processing, :monotonic, false)
    Proc(Nil).new(initializer, Pointer(Void).null).call
    Atomic::Ops.store(flag, :initialized, :release, false)
  ensure
    {% if flag?(:preview_mt) || flag?(:win32) %}
      state.unlock
    {% end %}
  end
end
