{% unless LibLLVM::IS_LT_130 %}
  @[Deprecated("The legacy pass manager was removed in LLVM 17. Use `LLVM::PassBuilderOptions` instead")]
{% end %}
class LLVM::FunctionPassManager
  def initialize(@unwrap : LibLLVM::PassManagerRef)
  end

  def run(mod : Module)
    changed = false
    run do |runner|
      mod.functions.each do |func|
        changed ||= runner.run(func)
      end
    end
    changed
  end

  def run(&)
    LibLLVM.initialize_function_pass_manager(self)

    runner = Runner.new(self)
    yield runner

    LibLLVM.finalize_function_pass_manager(self)

    self
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVM.dispose_pass_manager(@unwrap)
  end

  {% unless LibLLVM::IS_LT_130 %}
    @[Deprecated("The legacy pass manager was removed in LLVM 17. Use `LLVM::PassBuilderOptions` instead")]
  {% end %}
  struct Runner
    @fpm : FunctionPassManager

    def initialize(@fpm)
    end

    def run(f : LLVM::Function)
      LibLLVM.run_function_pass_manager(@fpm, f) != 0
    end
  end
end
