{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::ThreadSafeContext
  protected def initialize(@unwrap : LibLLVM::OrcThreadSafeContextRef)
  end

  def self.new
    new(LibLLVM.orc_create_new_thread_safe_context)
  end

  def self.new(ctx : LLVM::Context)
    {% if LibLLVM.has_method?(:orc_create_new_thread_safe_context_from_llvm_context) %}
      new(LibLLVM.orc_create_new_thread_safe_context_from_llvm_context(ctx))
    {% else %}
      raise NotImplementedError.new("LLVM::Orc::ThreadSafeContext.new(LLVM::Context)")
    {% end %}
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

  @[Deprecated("This function is removed in LLVM 21.")]
  def context : LLVM::Context
    {% if LibLLVM.has_method?(:orc_thread_safe_context_get_context) %}
      LLVM::Context.new(LibLLVM.orc_thread_safe_context_get_context(self), false)
    {% else %}
      raise NotImplementedError.new("LLVM::Orc::ThreadSafeContext#context")
    {% end %}
  end
end
