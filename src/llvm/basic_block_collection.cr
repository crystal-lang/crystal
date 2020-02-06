struct LLVM::BasicBlockCollection
  def initialize(@function : Function)
  end

  def append(name = "")
    context = LibLLVM.get_module_context(LibLLVM.get_global_parent(@function))
    BasicBlock.new LibLLVM.append_basic_block_in_context(context, @function, name)
  end

  def append(name = "")
    context = LibLLVM.get_module_context(LibLLVM.get_global_parent(@function))
    block = append name
    # builder = Builder.new(LibLLVM.create_builder_in_context(context), LLVM::Context.new(context, dispose_on_finalize: false))
    builder = Builder.new(LibLLVM.create_builder_in_context(context))
    builder.position_at_end block
    yield builder
    block
  end

  def each : Nil
    bb = LibLLVM.get_first_basic_block(@function)
    while bb
      yield LLVM::BasicBlock.new bb
      bb = LibLLVM.get_next_basic_block(bb)
    end
  end

  def []?(name : String)
    self.each do |bb|
      return bb if bb.name == name
    end
    nil
  end

  def [](name : String)
    self[name]? || raise IndexError.new
  end

  def alloca_block?
    self["alloca"]?
  end
end
