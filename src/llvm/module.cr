class LLVM::Module
  # We let a module store a reference to the context so that if
  # someone is still holding a reference to the module but not to
  # the context, the context won't be disposed (if the context is disposed,
  # the module will no longer be valid and segfaults will happen)

  getter context : Context

  {% if LibLLVM::IS_38 %}
    def initialize(@unwrap : LibLLVM::ModuleRef, @name : String, @context : Context)
      @owned = false
    end

    def name : String
      @name
    end
  {% else %} # LLVM >= 3.9
    def initialize(@unwrap : LibLLVM::ModuleRef, @context : Context)
      @owned = false
    end

    def name : String
      bytes = LibLLVM.get_module_identifier(self, out bytesize)
      String.new(Slice.new(bytes, bytesize))
    end

    def name=(name : String)
      LibLLVM.set_module_identifier(self, name, name.bytesize)
    end
  {% end %}

  def target=(target)
    LibLLVM.set_target(self, target)
  end

  def data_layout=(data : TargetData)
    {% if LibLLVM::IS_38 %}
      LibLLVM.set_data_layout(self, data.to_data_layout_string)
    {% else %} # LLVM >= 3.9
      LibLLVM.set_module_data_layout(self, data)
    {% end %}
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

  def write_bitcode_to_file(filename : String)
    LibLLVM.write_bitcode_to_file self, filename
  end

  {% unless LibLLVM::IS_38 || LibLLVM::IS_39 %}
    def write_bitcode_with_summary_to_file(filename : String)
      LibLLVMExt.write_bitcode_with_summary_to_file self, filename
    end
  {% end %}

  def write_bitcode_to_memory_buffer
    MemoryBuffer.new(LibLLVM.write_bitcode_to_memory_buffer self)
  end

  def write_bitcode_to_fd(fd : Int, should_close = false, buffered = false)
    LibLLVM.write_bitcode_to_fd(self, fd, should_close ? 1 : 0, buffered ? 1 : 0)
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

  def add_named_metadata_operand(name : String, value : Value) : Nil
    LibLLVM.add_named_metadata_operand(self, name, value)
  end

  def ==(other : self)
    @unwrap == other.@unwrap
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
end
