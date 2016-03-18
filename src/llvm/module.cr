class LLVM::Module
  getter unwrap : LibLLVM::ModuleRef
  getter name : String
  @owned : Bool

  def initialize(@name)
    @unwrap = LibLLVM.module_create_with_name @name
    @owned = false
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
    error = LibLLVM.verify_module(self, LLVM::VerifierFailureAction::ReturnStatusAction, out message)
    begin
      if error == 1
        raise "Module validation failed: #{String.new(message)}"
      end
    ensure
      LibLLVM.dispose_message(message)
    end
  end

  def print_to_file(filename)
    if LibLLVM.print_module_to_file(self, filename, out error_msg) != 0
      raise LLVM.string_and_dispose(error_msg)
    end
    self
  end

  def new_function_pass_manager
    FunctionPassManager.new LibLLVM.create_function_pass_manager_for_module(self)
  end

  def to_s(io)
    LLVM.to_io(LibLLVM.print_module_to_string(self), io)
    self
  end

  def to_unsafe
    @unwrap
  end

  def take_ownership
    if @owned
      yield
    else
      @owned = true
    end
  end

  def finalize
    return if @owned
    LibLLVM.dispose_module(@unwrap)
  end
end
