struct LLVM::BasicBlockCollection
  def initialize(@function : Function)
  end

  def append(name = "")
    context = LibLLVM.get_module_context(LibLLVM.get_global_parent(@function))
    BasicBlock.new LibLLVM.append_basic_block_in_context(context, @function, name)
  end

  def append(name = "")
    block = append name
    builder = Builder.new
    builder.position_at_end block
    yield builder
    block
  end
end
