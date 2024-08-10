{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::JITDylib
  protected def initialize(@unwrap : LibLLVM::OrcJITDylibRef)
  end

  def to_unsafe
    @unwrap
  end
end
