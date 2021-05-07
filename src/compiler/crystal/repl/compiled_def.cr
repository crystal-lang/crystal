require "./repl"

class Crystal::Repl
  class CompiledDef
    getter instructions
    getter local_vars
    getter def : Def

    def initialize(program : Program, @def : Def)
      @instructions = [] of Instruction
      @local_vars = LocalVars.new(program)
      @def.vars.try &.each do |name, var|
        # TODO don't always skip self
        next if name == "self"
        @local_vars.declare(name, var.type)
      end
    end
  end
end
