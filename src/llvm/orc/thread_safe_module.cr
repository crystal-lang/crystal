{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::ThreadSafeModule
  protected def initialize(@unwrap : LibLLVM::OrcThreadSafeModuleRef)
    @dispose_on_finalize = true
  end

  def self.new(llvm_mod : LLVM::Module, ts_ctx : ThreadSafeContext)
    llvm_mod.take_ownership { raise "Failed to take ownership of LLVM::Module" }
    new(LibLLVM.orc_create_new_thread_safe_module(llvm_mod, ts_ctx))
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LibLLVM.orc_dispose_thread_safe_module(self)
    @unwrap = LibLLVM::OrcThreadSafeModuleRef.null
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
