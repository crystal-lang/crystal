require "./repl"

class Crystal::Repl
  class CompiledDef
    getter instructions
    getter nodes
    getter local_vars
    getter def : Def
    getter args_bytesize

    def initialize(
      context : Context,
      @def : Def,
      @args_bytesize : Int32,
      @instructions : Array(Instruction) = [] of Instruction,
      @nodes : Hash(Int32, ASTNode) = {} of Int32 => ASTNode,
      @local_vars = LocalVars.new(context)
    )
    end
  end
end
