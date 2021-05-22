require "./repl"

class Crystal::Repl
  class CompiledBlock
    getter block
    getter instructions
    getter local_vars
    getter args_bytesize

    def initialize(@block : Block, @local_vars : LocalVars, @args_bytesize : Int32)
      @instructions = [] of Instruction
    end
  end
end
