struct LLVM::InstructionCollection
  include Enumerable(LLVM::Value)

  def initialize(@basic_block : BasicBlock)
  end

  def empty?
    llvm_first.null?
  end

  def first?
    value = llvm_first
    value ? Value.new(value) : nil
  end

  def first
    first?.not_nil!
  end

  private def llvm_first
    LibLLVM.get_first_instruction @basic_block
  end

  def each : Nil
    inst = llvm_first
    while inst
      yield LLVM::Value.new inst
      inst = LibLLVM.get_next_instruction(inst)
    end
  end
end
