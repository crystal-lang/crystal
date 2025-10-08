{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::LLJITBuilder
  protected def initialize(@unwrap : LibLLVM::OrcLLJITBuilderRef)
    @dispose_on_finalize = true
  end

  def self.new
    new(LibLLVM.orc_create_lljit_builder)
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LibLLVM.orc_dispose_lljit_builder(self)
    @unwrap = LibLLVM::OrcLLJITBuilderRef.null
  end

  def finalize
    if @dispose_on_finalize && @unwrap
      dispose
    end
  end

  def take_ownership(&) : Nil
    if @dispose_on_finalize
      @dispose_on_finalize = false
    else
      yield
    end
  end
end
