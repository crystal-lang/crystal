struct LLVM::BasicBlock
  def initialize(@unwrap : LibLLVM::BasicBlockRef)
  end

  def self.null
    LLVM::BasicBlock.new(Pointer(::Void).null.as(LibLLVM::BasicBlockRef))
  end

  def instructions
    InstructionCollection.new self
  end

  def delete
    LibLLVM.delete_basic_block self
  end

  def to_unsafe
    @unwrap
  end

  def name
    block_name = LibLLVMExt.basic_block_name(self)
    block_name ? LLVM.string_and_dispose(block_name) : nil
  end
end
