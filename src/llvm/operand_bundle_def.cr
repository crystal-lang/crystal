struct LLVM::OperandBundleDef
  def initialize(@unwrap : LibLLVMExt::OperandBundleDefRef)
  end

  def self.null
    LLVM::OperandBundleDef.new(Pointer(::Void).null.as(LibLLVMExt::OperandBundleDefRef))
  end

  def to_unsafe
    @unwrap
  end
end
