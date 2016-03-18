class LLVM::ModulePassManager
  @unwrap : LibLLVM::PassManagerRef

  def initialize
    @unwrap = LibLLVM.pass_manager_create
  end

  def add_target_data(target_data)
    LibLLVM.add_target_data target_data, self
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
