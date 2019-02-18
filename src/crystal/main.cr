lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

module Crystal
  @@main_fiber : Fiber?

  # Defines the main routine run by normal Crystal programs:
  #
  # - Initializes the GC
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
  def self.main(&block)
    # initialize Crystal core foundations, responsible to initialize enough of
    # the main user code, which includes corelib and stdlib initializations, and
    # that will be executed in a fiber:
    GC.init                   # memory allocator
    Fiber.init                # stack pool, fiber list
    Thread.init               # thread list, main thread (main fiber)
    Crystal::EventLoop.init   # I/O, sleep timer, ...
    Crystal::Scheduler.init   # fiber schedulers (single or multi-thread)
    Crystal::Hasher.init      # random hash seed
    Crystal::Signal.init      # signal handlers

    @@main_fiber = Fiber.current
    status = 0

    # start the main fiber:
    spawn(name: "main_user_code") do
      begin
        block.call
      rescue ex
        AtExitHandlers.exception = ex
        status = 1
      end

      status = AtExitHandlers.run(status)

      # flush buffered standard file descriptors, because they depend on event
      # loop and schedulers to run, then remove the nonblocking state, so any
      # further writes will still be printed after scheduler threads have been
      # stopped:
      STDOUT.sync = true
      STDOUT.blocking = true

      STDERR.sync = true
      STDERR.blocking = true
    ensure
      # main program is terminated: break out of the main loop, so `#main` can
      # be resumed and the program will exit:
      break_main_loop
    end

    # blocks until the main user code is finished:
    start_main_loop

    # done: exit with status
    status
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
  #   LibFoo.init_foo_and_invoke_main(argc, argv, ->Crystal.main)
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

  # Starts the main Crystal loop. Blocks until `#break_main_loop` is eventually
  # called from the main user code fiber.
  private def self.start_main_loop : Nil
    Crystal::Scheduler.reschedule
  end

  private def self.break_main_loop : Nil
    @@main_fiber.as(Fiber).enqueue
  end
end

# Main function that acts as C's main function.
# Invokes `Crystal.main`.
#
# Can be redefined. See `Crystal.main` for examples.
fun main(argc : Int32, argv : UInt8**) : Int32
  Crystal.main(argc, argv)
end
