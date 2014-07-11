struct LLVM::JITCompiler
  def initialize(mod)
    # if LibLLVM.create_jit_compiler_for_module(out @unwrap, mod, 3, out error) != 0
    if LibLLVM.create_mc_jit_compiler_for_module(out @unwrap, mod, nil, 0_u32, out error) != 0
      raise String.new(error)
    end
  end

  def run_function(func, args = [] of LibLLVM::GenericValueRef)
    ret = LibLLVM.run_function(self, func, args.length, args.buffer)
    GenericValue.new(ret)
  end

  def get_pointer_to_global(value)
    LibLLVM.get_pointer_to_global(self, value)
  end

  def to_unsafe
    @unwrap
  end
end
