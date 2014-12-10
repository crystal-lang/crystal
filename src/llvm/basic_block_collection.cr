struct LLVM::BasicBlockCollection
  def initialize(@function)
  end

  def append(name = "")
    BasicBlock.new LibLLVM.append_basic_block(@function, name)
  end

  def append(name = "")
    block = append name
    builder = Builder.new
    builder.position_at_end block
    yield builder
    block
  end
end
