require "./repl"

class Crystal::Repl
  # A block that's been compiled to bytecode.
  class CompiledDef
    # The def that was compiled.
    getter def : Def

    # The bytecode to execute the method.
    getter instructions : Array(Instruction)

    # The nodes to refer from the instructions (by index)
    getter nodes : Hash(Int32, ASTNode)

    # Local variables for the method.
    getter local_vars : LocalVars

    # What's `self` for this method.
    getter owner : Type

    # How many bytes occupy the method arguments.
    getter args_bytesize : Int32

    def initialize(
      context : Context,
      @def : Def,
      @owner : Type,
      @args_bytesize : Int32,
      @instructions : Array(Instruction) = [] of Instruction,
      @nodes : Hash(Int32, ASTNode) = {} of Int32 => ASTNode,
      @local_vars = LocalVars.new(context)
    )
    end
  end
end
