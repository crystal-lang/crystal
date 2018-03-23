struct LLVM::InstructionCollection
  def initialize(@basic_block : BasicBlock)
  end

  def empty?
    llvm_first.null?
  end

  def first?
    if value = llvm_first
      Value.new(value)
    end
  end

  def first
    first?.not_nil!
  end

  private def llvm_first
    LibLLVM.get_first_instruction @basic_block
  end
end
