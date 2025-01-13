# This file defines two functions expected by the compiler:
#
# - `__crystal_once_init`: executed only once at the beginning of the program
#   and, for the legacy implementation, the result is passed on each call to
#   `__crystal_once`.
#
# - `__crystal_once`: called each time a constant or class variable has to be
#   initialized and is its responsibility to verify the initializer is executed
#   only once and to fail on recursion.
#
# Also defines the `Crystal.once(flag, &)` method used to protect lazy
# initialization of class getters & properties.
#
# A `Mutex` is used to avoid race conditions between threads and fibers.

{% if compare_versions(Crystal::VERSION, "1.16.0-dev") >= 0 %}
  # This implementation uses an enum over the initialization flag pointer for
  # each value to find infinite loops and raise an error.

  module Crystal
    # :nodoc:
    enum OnceState : Int8
      Processing    = -1
      Uninitialized =  0
      Initialized   =  1
    end

    @@once_mutex = uninitialized Mutex

    # :nodoc:
    def self.once_mutex=(@@once_mutex : Mutex)
    end

    # :nodoc:
    # Identical to `__crystal_once` but takes a block with possibly closured
    # data. Used by `class_[getter|property](declaration, &block)` for example.
    @[AlwaysInline]
    def self.once(flag : OnceState*, &block) : Nil
      return if flag.value.initialized?
      once(flag, block.pointer, block.closure_data)
      Intrinsics.unreachable unless flag.value.initialized?
    end

    # :nodoc:
    # Using @[NoInline] so LLVM optimizes for the hot path (var already
    # initialized).
    @[NoInline]
    def self.once(flag : OnceState*, initializer : Void*, closure_data : Void*) : Nil
      @@once_mutex.synchronize do
        case flag.value
        in .initialized?
          return
        in .uninitialized?
          flag.value = :processing
          Proc(Nil).new(initializer, closure_data).call
          flag.value = :initialized
        in .processing?
          raise "Recursion while initializing class variables and/or constants"
        end
      end

      # safety check, and allows to safely call `Intrinsics.unreachable` in
      # `__crystal_once`
      unless flag.value.initialized?
        System.print_error "BUG: failed to initialize constant or class variable\n"
        LibC._exit(1)
      end
    end
  end

  # :nodoc:
  fun __crystal_once_init : Nil
    Thread.init
    Fiber.init
    Crystal.once_mutex = Mutex.new(:reentrant)
  end

  # :nodoc:
  #
  # Using `@[AlwaysInline]` allows LLVM to optimize const accesses. Since this
  # is a `fun` the function will still appear in the symbol table, though it
  # will never be called.
  @[AlwaysInline]
  fun __crystal_once(flag : Crystal::OnceState*, initializer : Void*) : Nil
    return if flag.value.initialized?

    Crystal.once(flag, initializer, Pointer(Void).null)

    # tell LLVM that it can optimize away repeated `__crystal_once` calls for
    # this global (e.g. repeated access to constant in a single funtion);
    # this is truly unreachable otherwise `Crystal.once` would have panicked
    Intrinsics.unreachable unless flag.value.initialized?
  end
{% else %}
  # This implementation uses a global array to store the initialization flag
  # pointers for each value to find infinite loops and raise an error.

  module Crystal
    # :nodoc:
    class OnceState
      @mutex = Mutex.new(:reentrant)
      @rec = [] of Bool*

      @[NoInline]
      def once(flag : Bool*, initializer : Void*, closure_data : Void*)
        return if flag.value

        @mutex.synchronize do
          return if flag.value

          if @rec.includes?(flag)
            raise "Recursion while initializing class variables and/or constants"
          end
          @rec << flag

          Proc(Nil).new(initializer, closure_data).call
          flag.value = true

          @rec.pop
        end
      end
    end

    @@once_state = uninitialized OnceState

    # :nodoc:
    def self.once_state=(@@once_state : OnceState)
    end

    # :nodoc:
    @[AlwaysInline]
    def self.once(flag : Bool*, &block) : Nil
      return if flag.value
      @@once_state.once(flag, block.pointer, block.closure_data)
      Intrinsics.unreachable unless flag.value
    end
  end

  # :nodoc:
  fun __crystal_once_init : Void*
    Thread.init
    Fiber.init
    (Crystal.once_state = Crystal::OnceState.new).as(Void*)
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
    return if flag.value
    state.as(Crystal::OnceState).once(flag, initializer, Pointer(Void).null)
    Intrinsics.unreachable unless flag.value
  end
{% end %}
