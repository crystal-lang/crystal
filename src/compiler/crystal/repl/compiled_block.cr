require "./repl"

class Crystal::Repl
  class CompiledBlock
    getter block
    getter instructions
    getter nodes
    getter local_vars

    # How many bytes occupy the block args
    getter args_bytesize

    # What's the byte offset where the local vars of this block start
    getter locals_bytesize_start

    # What's the byte offset where the local vars of this block end
    getter locals_bytesize_end

    def initialize(@block : Block,
                   @local_vars : LocalVars,
                   @args_bytesize : Int32,
                   @locals_bytesize_start : Int32,
                   @locals_bytesize_end : Int32)
      @instructions = [] of Instruction
      @nodes = {} of Int32 => ASTNode
    end
  end
end
