class LLVM::PassManagerBuilder
  def initialize
    @unwrap = LibLLVM.pass_manager_builder_create
  end

  def opt_level=(level)
    LibLLVM.pass_manager_builder_set_opt_level self, level
  end

  def size_level=(level)
    LibLLVM.pass_manager_builder_set_size_level self, level
  end

  def disable_unroll_loops=(value)
    LibLLVM.pass_manager_builder_set_disable_unroll_loops self, value ? 1 : 0
  end

  def disable_simplify_lib_calls=(value)
    LibLLVM.pass_manager_builder_set_disable_simplify_lib_calls self, value ? 1 : 0
  end

  def use_inliner_with_threshold=(threshold)
    LibLLVM.pass_manager_builder_use_inliner_with_threshold self, threshold
  end

  def populate(pm : FunctionPassManager)
    LibLLVM.pass_manager_builder_populate_function_pass_manager self, pm
  end

  def populate(pm : ModulePassManager)
    LibLLVM.pass_manager_builder_populate_module_pass_manager self, pm
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVM.dispose_pass_manager_builder(@unwrap)
  end
end
