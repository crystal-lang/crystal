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

  def print_to_file(filename)
    if LibLLVM.print_module_to_file(self, filename, out error_msg) != 0
      raise String.new(error_msg)
    end
    self
  end

  def new_function_pass_manager
    FunctionPassManager.new LibLLVM.create_function_pass_manager_for_module(self)
  end

  def inspect(io)
    LLVM.to_io(LibLLVM.print_module_to_string(self), io)
    self
  end

  def to_unsafe
    @unwrap
  end
end
