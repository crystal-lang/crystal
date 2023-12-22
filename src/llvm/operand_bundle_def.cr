struct LLVM::OperandBundleDef
  def initialize(@unwrap : LibLLVM::OperandBundleRef)
  end

  def self.null
    new(Pointer(::Void).null.as(LibLLVM::OperandBundleRef))
  end

  def to_unsafe
    @unwrap
  end

  def dispose
    {{ LibLLVM::IS_LT_180 ? LibLLVMExt : LibLLVM }}.dispose_operand_bundle(@unwrap) if @unwrap
  end
end
