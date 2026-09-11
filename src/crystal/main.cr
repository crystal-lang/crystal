lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

module Crystal
  {% begin %}
  # Defines the main routine run by normal Crystal programs:
  #
  # - Initializes runtime requirements (GC, ...)
  # - Invokes the given *block*
  # - Handles unhandled exceptions
  # - Invokes `at_exit` handlers
  # - Flushes `STDOUT` and `STDERR`
  #
  # This method can be invoked if you need to define a custom
  # main (as in C main) function, doing all the above steps.
  #
  # For example:
  #
  # ```
  # fun main(argc : Int32, argv : UInt8**) : Int32
  #   Crystal.main do
  #     elapsed = Time.measure do
  #       Crystal.main_user_code(argc, argv)
  #     end
  #     puts "Time to execute program: #{elapsed}"
  #   end
  # end
  # ```
  #
  # Note that the above is really just an example, almost the
  # same can be accomplished with `at_exit`. But in some cases
  # redefinition of C's main is needed.
  def self.main(&block : ->)
    {% if flag?(:tracing) %} Crystal::Tracing.init {% end %}

    GC.init
    init_runtime

    {% if !flag?(:without_mt) && (!flag?(:preview_mt) || flag?(:execution_context)) %}
      # Run main user code in a fiber so the main program doesn't run on a
      # thread's stack. This avoids situations where thread B would pick and
      # resume the main fiber of thread A (crashes on aarch64-darwin), and
      # allows every fiber to run on the same stack size.
      pointer = Crystal::System::Fiber.allocate_stack(Fiber::StackPool::STACK_SIZE, protect: true)
      stack = Fiber::Stack.new(pointer, Fiber::StackPool::STACK_SIZE, reusable: true)

      main_user_code_fiber = Fiber.new(stack) do
        status =
          begin
            block.call
            0
          rescue ex
            1
          end
        LibC.exit(exit(status , ex))
      end
      Fiber::ExecutionContext.thread_pool.enter_main_thread_loop(main_user_code_fiber)

      # unreachable (the above never returns)
      1
    {% else %}
      status =
        begin
          yield
          0
        rescue ex
          1
        end
      exit(status, ex)
    {% end %}
  end
  {% end %}

  # :nodoc:
  #
  # Manually initializes parts of the stdlib that must be setup before we can
  # execute main user code, that will initialize globals, runtime (kernel) then
  # run the actual program.
  def self.init_runtime : Nil
    Thread.init
    Fiber.init

    Crystal::Once.init

    {% if !flag?(:without_mt) && (!flag?(:preview_mt) || flag?(:execution_context)) %}
      Fiber::ExecutionContext.init
    {% end %}
  end

  # :nodoc:
  def self.exit(status : Int32, exception : Exception?) : Int32
    status = Crystal::AtExitHandlers.run status, exception

    if exception
      STDERR.print "Unhandled exception: "
      exception.inspect_with_backtrace(STDERR)
    end

    ignore_stdio_errors { STDOUT.flush }
    ignore_stdio_errors { STDERR.flush }

    status
  end

  # :nodoc:
  def self.ignore_stdio_errors(&)
    yield
  rescue IO::Error
  end

  # Main method run by all Crystal programs at startup.
  #
  # This setups up the GC, invokes your program, rescuing
  # any handled exception, and then runs `at_exit` handlers.
  #
  # This method is automatically invoked for you, so you
  # don't need to invoke it.
  #
  # However, if you need to define a special main C function,
  # you can redefine main and invoke `Crystal.main` from it:
  #
  # ```
  # fun main(argc : Int32, argv : UInt8**) : Int32
  #   # some setup before Crystal main
  #   Crystal.main(argc, argv)
  #   # some cleanup logic after Crystal main
  # end
  # ```
  #
  # The `Crystal.main` can also be passed as a callback:
  #
  # ```
  # fun main(argc : Int32, argv : UInt8**) : Int32
  #   LibFoo.init_foo_and_invoke_main(argc, argv, ->Crystal.main(Int32, UInt8**))
  # end
  # ```
  #
  # Note that before `Crystal.main` is invoked the GC
  # is not setup yet, so nothing that allocates memory
  # in Crystal (like `new` for classes) can be used.
  def self.main(argc : Int32, argv : UInt8**)
    main do
      main_user_code(argc, argv)
    end
  rescue ex
    Crystal::System.print_exception "Unhandled exception", ex
    1
  end

  # Executes the main user code. This normally is executed
  # after initializing the GC and before executing `at_exit` handlers.
  #
  # You should never invoke this method unless you need to
  # redefine C's main function. See `Crystal.main` for
  # more details.
  def self.main_user_code(argc : Int32, argv : UInt8**)
    LibCrystalMain.__crystal_main(argc, argv)
  end
end

{% unless flag?(:without_main) %}
  # Main function that acts as C's main function.
  # Invokes `Crystal.main`.
  #
  # Can be redefined. See `Crystal.main` for examples.
  #
  # On Windows the actual entry point is `wmain`, but there is no need to redefine
  # that. See the file required below for details.
  fun main(argc : Int32, argv : UInt8**) : Int32
    Crystal.main(argc, argv)
  end

  {% if flag?(:interpreted) %}
    # the interpreter doesn't call Crystal.main(&)
    Crystal.init_runtime
  {% elsif flag?(:win32) %}
    require "./system/win32/wmain"
  {% elsif flag?(:wasi) %}
    require "./system/wasi/main"
  {% else %}
    require "./system/unix/main"
  {% end %}
{% end %}
