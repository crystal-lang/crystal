class LLVM::JITCompiler
  def initialize(mod)
    # JIT compilers own an LLVM::Module, and when they are disposed the module is disposed,
    # so we must prevent the module from being dispose when the GC will want to free it.
    mod.take_ownership { raise "Can't create two JIT compilers for the same module" }

    # if LibLLVM.create_jit_compiler_for_module(out @unwrap, mod, 3, out error) != 0
    if LibLLVM.create_mc_jit_compiler_for_module(out @unwrap, mod, nil, 0, out error) != 0
      raise LLVM.string_and_dispose(error)
    end

    @finalized = false
  end

  def self.new(mod)
    jit = new(mod)
    yield jit ensure jit.dispose
  end

  def run_function(func, context : Context)
    ret = LibLLVM.run_function(self, func, 0, nil)
    GenericValue.new(ret, context)
  end

  def run_function(func, args : Array(LLVM::GenericValue), context : Context)
    ret = LibLLVM.run_function(self, func, args.size, (args.to_unsafe.as(LibLLVM::GenericValueRef*)))
    GenericValue.new(ret, context)
  end

  def get_pointer_to_global(value)
    LibLLVM.get_pointer_to_global(self, value)
  end

  def to_unsafe
    @unwrap
  end

  def dispose
    return if @finalized
    @finalized = true
    finalize
  end

  def finalize
    return if @finalized
    LibLLVM.dispose_execution_engine(@unwrap)
  end
end
