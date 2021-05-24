require "./repl"

class Crystal::Repl
  class CompiledDef
    getter instructions
    getter local_vars
    getter def : Def
    getter args_bytesize

    def initialize(
      context : Context,
      @def : Def,
      @args_bytesize : Int32,
      @instructions : Array(Instruction) = [] of Instruction,
      @local_vars = LocalVars.new(context)
    )
    end
  end
end
