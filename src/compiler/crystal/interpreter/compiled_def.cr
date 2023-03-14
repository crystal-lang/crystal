require "./repl"

class Crystal::Repl
  # A block that's been compiled to bytecode.
  class CompiledDef
    # The def that was compiled.
    getter def : Def

    # The bytecode to execute the method.
    getter instructions : CompiledInstructions

    # Local variables for the method.
    getter local_vars : LocalVars

    # What's `self` for this method.
    getter owner : Type

    # How many bytes occupy the method arguments.
    getter args_bytesize : Int32

    property closure_context : ClosureContext?

    def initialize(
      context : Context,
      @def : Def,
      @owner : Type,
      @args_bytesize : Int32,
      @instructions : CompiledInstructions = CompiledInstructions.new,
      @local_vars = LocalVars.new(context)
    )
    end
  end
end
