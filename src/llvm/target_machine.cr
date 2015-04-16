struct LLVM::TargetMachine
  def initialize(@unwrap)
  end

  def target
    target = LibLLVM.get_target_machine_target(self)
    target ? Target.new(target) : raise "Couldn't get target"
  end

  def data_layout
    layout = LibLLVM.get_target_machine_data(self)
    layout ? TargetData.new(layout) : raise "Missing layout for #{self}"
  end

  def triple
    triple_c = LibLLVM.get_target_machine_triple(self)
    triple = String.new(triple_c)
    LibLLVM.dispose_message(triple_c)
    triple
  end

  def emit_obj_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVM::CodeGenFileType::ObjectFile
  end

  def emit_asm_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVM::CodeGenFileType::AssemblyFile
  end

  private def emit_to_file(llvm_mod, filename, type)
    status = LibLLVM.target_machine_emit_to_file(self, llvm_mod, filename, type, out error_msg)
    unless status == 0
      raise String.new(error_msg)
    end
    true
  end

  def abi
    triple = self.triple
    case triple
    when /x86_64/
      ABI::X86_64.new(self)
    when /i386|i686/
      ABI::X86.new(self)
    else
      raise "Unsupported ABI for target triple: #{triple}"
    end
  end

  def to_unsafe
    @unwrap
  end
end
