struct LLVM::Module
  getter :unwrap

  def initialize(name)
    @unwrap = LibLLVM.module_create_with_name name
  end

  def target=(target)
    LibLLVM.set_target(self, target)
  end

  def data_layout=(data)
    LibLLVM.set_data_layout(self, data)
  end

  def dump
    LibLLVM.dump_module(self)
  end

  def functions
    FunctionCollection.new(self)
  end

  def globals
    GlobalCollection.new(self)
  end

  def write_bitcode(filename : String)
    LibLLVM.write_bitcode_to_file self, filename
  end

  def verify
    if LibLLVM.verify_module(self, LibLLVM::VerifierFailureAction::ReturnStatusAction, out message) == 1
      raise "Module validation failed: #{String.new(message)}"
    end
  end

  def to_unsafe
    @unwrap
  end
end
