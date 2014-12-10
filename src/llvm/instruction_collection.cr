struct LLVM::InstructionCollection
  def initialize(@basic_block)
  end

  def empty?
    llvm_first.nil?
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
end
