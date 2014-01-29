class LLVM::Context
  def self.global
    LibLLVM.get_global_context
  end
end
