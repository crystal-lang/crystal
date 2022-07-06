require "./repl"

class Crystal::Repl
  # A block that's been compiled to bytecode.
  class CompiledBlock
    # The block that was compiled.
    getter block : Block

    # The bytecode to execute the block.
    getter instructions : CompiledInstructions

    # How many bytes occupy the block args
    getter args_bytesize : Int32

    # What's the byte offset where the local vars of this block start
    getter locals_bytesize_start : Int32

    # What's the byte offset where the local vars of this block end
    getter locals_bytesize_end : Int32

    # Local variables for the block (they might reference variables outside of the block)
    property! local_vars : LocalVars

    property closure_context : ClosureContext?

    def initialize(@block : Block,
                   @args_bytesize : Int32,
                   @locals_bytesize_start : Int32,
                   @locals_bytesize_end : Int32)
      @instructions = CompiledInstructions.new
    end
  end
end
