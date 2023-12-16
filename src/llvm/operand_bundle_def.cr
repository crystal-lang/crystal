struct LLVM::OperandBundleDef
  def initialize(@unwrap : LibLLVM::OperandBundleRef)
  end

  def self.null
    new(Pointer(::Void).null.as(LibLLVM::OperandBundleRef))
  end

  def to_unsafe
    @unwrap
  end
end
