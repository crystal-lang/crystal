module Crystal
  # :nodoc:
  #
  # This is a support module to implement the interpreter.
  module Interpreter
    # Returns the fiber associated to the currently running interpreter.
    @[Primitive(:interpreter_current_fiber)]
    def self.current_fiber : Void*
    end

    # Spawns a new interpreter that will run the given fiber
    # by calling `fiber_main` (which is a `Proc(Fiber, Nil)`)
    # and passing `fiber` to it.
    #
    # The spawned fiber isn't automatically enqueued in the
    # interpreter's event loop scheduler.
    #
    # Returns the spawned fiber.
    @[Primitive(:interpreter_spawn)]
    def self.spawn(fiber : Fiber, fiber_main : Void*) : Void*
    end
  end
end
