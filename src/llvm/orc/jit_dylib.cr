@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::JITDylib
  protected def initialize(@unwrap : LibLLVM::OrcJITDylibRef)
  end

  def to_unsafe
    @unwrap
  end
end
