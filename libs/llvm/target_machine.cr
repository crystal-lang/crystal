struct LLVM::TargetMachine
  def initialize(@unwrap)
  end

  def data_layout
    layout = LibLLVM.get_target_machine_data(self)
    layout ? TargetDataLayout.new(layout) : nil
  end

  def triple
    triple_c = LibLLVM.get_target_machine_triple(self)
    triple = String.new(triple_c)
    LibLLVM.dispose_message(triple_c)
    triple
  end

  def emit_obj_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LibLLVM::CodeGenFileType::ObjectFile
  end

  def emit_asm_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LibLLVM::CodeGenFileType::AssemblyFile
  end

  private def emit_to_file(llvm_mod, filename, type)
    status = LibLLVM.target_machine_emit_to_file(self, llvm_mod, filename, type, out error_msg)
    unless status == 0
      raise String.new(error_msg)
    end
    true
  end

  def to_unsafe
    @unwrap
  end
end
