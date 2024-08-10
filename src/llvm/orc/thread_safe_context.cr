{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::ThreadSafeContext
  protected def initialize(@unwrap : LibLLVM::OrcThreadSafeContextRef)
  end

  def self.new
    new(LibLLVM.orc_create_new_thread_safe_context)
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LibLLVM.orc_dispose_thread_safe_context(self)
    @unwrap = LibLLVM::OrcThreadSafeContextRef.null
  end

  def finalize
    if @unwrap
      dispose
    end
  end

  def context : LLVM::Context
    LLVM::Context.new(LibLLVM.orc_thread_safe_context_get_context(self), false)
  end
end
