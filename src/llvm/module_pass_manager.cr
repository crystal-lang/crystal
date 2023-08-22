{% unless LibLLVM::IS_LT_130 %}
  @[Deprecated("The legacy pass manager was removed in LLVM 17. Use `LLVM::PassBuilderOptions` instead")]
{% end %}
class LLVM::ModulePassManager
  def initialize
    @unwrap = LibLLVM.pass_manager_create
  end

  def run(mod)
    LibLLVM.run_pass_manager(self, mod) != 0
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVM.dispose_pass_manager(@unwrap)
  end
end
