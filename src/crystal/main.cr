lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

module Crystal
  {% if !flag?(:win32) %}
    # On POSIX targets, any closed fd can be recycled, and that includes fd 0, 1
    # and 2 that only have special meaning, not special treatment. If stdout is
    # closed, then the next call to open or socket will recycle fd 1.
    #
    # If such a case happens before we define STDIN, STDOUT and STDERR, then we
    # can miss that the standard stream is actually closed, and mistake the newly
    # opened fd to be the standard stream.
    #
    # For example, under some configuration (e.g. USE_MMAP=1 + USE_MMAP_ANON=0)
    # the BDW GC will open /dev/zero and reuse any of 0, 1 or 2 for it if any
    # stream is closed. The same can happen for crystal/tracing with
    # CRYSTAL_TRACE_FILE.
    #
    # We thus store the state ASAP when the program starts, then use it to
    # create the STDIN, ORIGINAL_STDIN, and others, as closed IO objects.
    @@stdio_closed = uninitialized {Bool, Bool, Bool}

    # :nodoc:
    private def self.init_stdio_closed : Nil
      # check for closed stdio fds
      closed_stdin = LibC.fcntl(0, LibC::F_GETFL) == -1
      closed_stdout = LibC.fcntl(1, LibC::F_GETFL) == -1
      closed_stderr = LibC.fcntl(2, LibC::F_GETFL) == -1

      # reopen closed fds (guaranteed to be the smallest number)
      LibC.open("/dev/null", LibC::O_RDONLY | LibC::O_CLOEXEC, 0) if closed_stdin
      LibC.open("/dev/null", LibC::O_WRONLY | LibC::O_CLOEXEC, 0) if closed_stdout
      LibC.open("/dev/null", LibC::O_WRONLY | LibC::O_CLOEXEC, 0) if closed_stderr

      # save the closed state for when we create the IO objects
      @@stdio_closed = {closed_stdin, closed_stdout, closed_stderr}
    end

    # :nodoc:
    def self.stdio_closed?(fd)
      @@stdio_closed[fd]
    end
  {% else %}
    # :nodoc:
    def self.stdio_closed?(fd)
      false
    end
  {% end %}

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
  #
  # @[Deprecated("Crystal.main(&) is unsafe since Crystal 1.23. Use Crystal.main(argc, argv) instead.")]
  def self.main(&block : ->)
    init_runtime
    run_main(&block)
  end

  # :nodoc:
  #
  # Manually initializes parts of the corelib and stdlib that must be setup
  # before we can execute main user code, that will initialize globals, runtime
  # (kernel) then run the actual program.
  def self.init_runtime : Nil
    {% unless flag?(:interpreted) %}
      {% unless flag?(:win32) %} init_stdio_closed {% end %}
      {% if flag?(:tracing) %} Crystal::Tracing.init {% end %}
      GC.init
    {% end %}

    Thread.init
    Fiber.init
    Thread.current # define main thread & main fiber
    Crystal::Once.init

    {% if !flag?(:without_mt) && (!flag?(:preview_mt) || flag?(:execution_context)) %}
      Fiber::ExecutionContext.init
    {% end %}
  end

  {% begin %}
  private def self.run_main(&block : ->) : Int32
    {% if !flag?(:without_mt) && (!flag?(:preview_mt) || flag?(:execution_context)) %}
      # Run main user code in a fiber so the main program doesn't run on a
      # thread's stack. This avoids situations where thread B would pick and
      # resume the main fiber of thread A (crashes on aarch64-darwin), and
      # allows every fiber to run on the same stack size.
      main_user_code_fiber = Fiber.new(-> {
        status =
          begin
            block.call
            0
          rescue ex
            1
          end
        status = exit(status , ex) rescue 1
        LibC.exit(status)
      })
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
  def self.exit(status : Int32, exception : Exception?) : Int32
    status = Crystal::AtExitHandlers.run status, exception

    if exception && !STDERR.closed?
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
  # - Initializes runtime requirements (GC, ...)
  # - Invokes the given *block*
  # - Handles unhandled exceptions
  # - Invokes `at_exit` handlers
  # - Flushes `STDOUT` and `STDERR`
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
    init_runtime
    run_main_with_user_code(argc, argv)
  rescue ex
    Crystal::System.print_exception "Unhandled exception", ex
    1
  end

  # DO NOT MANUALLY INLINE: this must be a distinct method because run_main
  # captures the block and silently closures the argc and argv variables,
  # which silently initializes the GC before we call init_runtime (oh no).
  private def self.run_main_with_user_code(argc : Int32, argv : UInt8**)
    run_main do
      main_user_code(argc, argv)
    end
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
