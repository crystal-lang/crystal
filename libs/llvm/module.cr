struct LLVM::Module
  def initialize(name)
    @module = LibLLVM.module_create_with_name name
  end

  def dump
    LibLLVM.dump_module(@module)
  end

  def functions
    FunctionCollection.new(self)
  end

  def globals
    GlobalCollection.new(self)
  end

  def llvm_module
    @module
  end

  def write_bitcode(filename : String)
    LibLLVM.write_bitcode_to_file @module, filename
  end

  def verify
    if LibLLVM.verify_module(@module, LibLLVM::VerifierFailureAction::ReturnStatusAction, out message) == 1
      raise "Module validation failed: #{String.new(message)}"
    end
  end
end
