lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

# :nodoc:
def _crystal_main(argc : Int32, argv : UInt8**)
  # TODO: remove this method and embed this inside
  # Crystal.main. A bug in Crystal 0.23.1 prevents invoking
  # __crystal_main from anywhere except the top level.
  LibCrystalMain.__crystal_main(argc, argv)
end

module Crystal
  @@stdin_is_blocking = false
  @@stdout_is_blocking = false
  @@stderr_is_blocking = false

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
    GC.init

    remember_blocking_state

    status =
      begin
        yield
        0
      rescue ex
        1
      end

    AtExitHandlers.run status
    ex.inspect_with_backtrace STDERR if ex
    STDOUT.flush
    STDERR.flush

    restore_blocking_state

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
    _crystal_main(argc, argv)
  end

  # :nodoc:
  def self.remember_blocking_state
    @@stdin_is_blocking = IO::FileDescriptor.fcntl(0, LibC::F_GETFL) & LibC::O_NONBLOCK == 0
    @@stdout_is_blocking = IO::FileDescriptor.fcntl(1, LibC::F_GETFL) & LibC::O_NONBLOCK == 0
    @@stderr_is_blocking = IO::FileDescriptor.fcntl(2, LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  # :nodoc:
  def self.restore_blocking_state
    STDIN.blocking = @@stdin_is_blocking
    STDOUT.blocking = @@stdout_is_blocking
    STDERR.blocking = @@stderr_is_blocking
  end
end

# Main function that acts as C's main function.
# Invokes `Crystal.main`.
#
# Can be redefined. See `Crystal.main` for examples.
fun main(argc : Int32, argv : UInt8**) : Int32
  Crystal.main(argc, argv)
end
