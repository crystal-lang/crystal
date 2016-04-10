class LLVM::Context
  def initialize(@unwrap : LibLLVM::ContextRef)
  end

  def self.global
    new LibLLVM.get_global_context
  end

  def to_unsafe
    @unwrap
  end
end
