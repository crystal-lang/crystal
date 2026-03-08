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

    # Returns the resumable value from the interpreter's fiber.
    @[Primitive(:interpreter_fiber_resumable)]
    def self.fiber_resumable(context) : LibC::Long
    end

    {% if compare_versions(Crystal::VERSION, "1.15.0-dev") >= 0 %}
      @[Primitive(:interpreter_signal_descriptor)]
      def self.signal_descriptor(fd : Int32) : Nil
      end

      @[Primitive(:interpreter_signal)]
      def self.signal(signum : Int32, handler : Int32) : Nil
      end
    {% end %}
  end
end
