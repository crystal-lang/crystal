# This file defines two functions expected by the compiler:
#
# - `__crystal_once_init`: executed only once at the beginning of the program
#   and, for the legacy implementation, the result is passed on each call to
#   `__crystal_once`.
#
# - `__crystal_once`: called each time a constant or class variable has to be
#   initialized and is its responsibility to verify the initializer is executed
#   only once and to fail on recursion.

# In multithread mode a mutex is used to avoid race conditions between threads.
#
# On Win32, `Crystal::System::FileDescriptor#@@reader_thread` spawns a new
# thread even without the `preview_mt` flag, and the thread can also reference
# Crystal constants, leading to race conditions, so we always enable the mutex.

{% if compare_versions(Crystal::VERSION, "1.15.0-dev") >= 0 %}
  # This implementation uses an enum over the initialization flag pointer for
  # each value to find infinite loops and raise an error.

  module Crystal
    enum OnceState : Int8
      Processing    = -1
      Uninitialized = 0
      Initialized   = 1
    end

    {% if flag?(:preview_mt) || flag?(:win32) %}
      @@once_mutex = uninitialized Mutex
      class_property once_mutex : Mutex
    {% end %}

    # Using @[NoInline] so LLVM optimizes for the hot path (var already
    # initialized).
    @[NoInline]
    def self.once(flag : OnceState*, initializer : Void*) : Nil
      {% if flag?(:preview_mt) || flag?(:win32) %}
        Crystal.once_mutex.synchronize { once_exec(flag, initializer) }
      {% else %}
        once_exec(flag, initializer)
      {% end %}
    end

    private def self.once_exec(flag : OnceState*, initializer : Void*) : Nil
      case flag.value
      in .initialized?
        return
      in .uninitialized?
        flag.value = :processing
        Proc(Nil).new(initializer, Pointer(Void).null).call
        flag.value = :initialized
      in .processing?
        raise "Recursion while initializing class variables and/or constants"
      end
    end
  end

  # :nodoc:
  fun __crystal_once_init : Nil
    {% if flag?(:preview_mt) || flag?(:win32) %}
      Crystal.once_mutex = Mutex.new(:reentrant)
    {% end %}
  end

  # :nodoc:
  #
  # Using `@[AlwaysInline]` allows LLVM to optimize const accesses. Since this
  # is a `fun` the function will still appear in the symbol table, though it
  # will never be called.
  @[AlwaysInline]
  fun __crystal_once(flag : Int8*, initializer : Void*) : Nil
    flag = flag.as(Crystal::OnceState*)
    Crystal.once(flag, initializer) unless flag.value.initialized?
  end
{% else %}
  # This implementation uses a global array to store the initialization flag
  # pointers for each value to find infinite loops and raise an error.

  # :nodoc:
  class Crystal::OnceState
    @rec = [] of Bool*

    def once(flag : Bool*, initializer : Void*)
      unless flag.value
        if @rec.includes?(flag)
          raise "Recursion while initializing class variables and/or constants"
        end
        @rec << flag

        Proc(Nil).new(initializer, Pointer(Void).null).call
        flag.value = true

        @rec.pop
      end
    end

    {% if flag?(:preview_mt) || flag?(:win32) %}
      @mutex = Mutex.new(:reentrant)

      def once(flag : Bool*, initializer : Void*)
        unless flag.value
          @mutex.synchronize do
            previous_def
          end
        end
      end
    {% end %}
  end

  # :nodoc:
  fun __crystal_once_init : Void*
    Crystal::OnceState.new.as(Void*)
  end

  # :nodoc:
  fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
    state.as(Crystal::OnceState).once(flag, initializer)
  end
{% end %}
