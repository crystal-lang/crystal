class LLVM::Context
  @unwrap : LibLLVM::ContextRef

  def initialize(@unwrap)
  end

  def self.global
    new LibLLVM.get_global_context
  end

  def to_unsafe
    @unwrap
  end
end
