require "./repl"

class Crystal::Repl
  class CompiledDef
    getter instructions
    getter local_vars
    getter def : Def

    def initialize(program : Program, @def : Def)
      @instructions = [] of Instruction
      @local_vars = LocalVars.new(program)
    end
  end
end
