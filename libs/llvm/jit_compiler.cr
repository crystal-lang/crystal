require "wrapper"

class LLVM::JITCompiler
  include LLVM::Wrapper

  def initialize(mod)
    # if LibLLVM.create_jit_compiler_for_module(out @jit, mod.llvm_module, 3, out error) != 0
    if LibLLVM.create_mc_jit_compiler_for_module(out @jit, mod.llvm_module, nil, 0_u32, out error) != 0
      raise String.new(error)
    end
  end

  def wrapped_pointer
    @jit
  end

  def run_function(func, args = [] of LibLLVM::GenericValueRef)
    ret = LibLLVM.run_function(@jit, func.llvm_function, args.length, args.buffer)
    GenericValue.new(ret)
  end

  def get_pointer_to_global(value)
    LibLLVM.get_pointer_to_global(@jit, value)
  end
end
