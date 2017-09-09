class LLVM::TargetMachine
  def initialize(@unwrap : LibLLVM::TargetMachineRef)
  end

  def target
    target = LibLLVM.get_target_machine_target(self)
    target ? Target.new(target) : raise "Couldn't get target"
  end

  def data_layout
    @layout ||= begin
      layout = {% if LibLLVM::IS_38 %}
                 LibLLVM.get_target_machine_data(self)
               {% else %} # LLVM >= 3.9
                 LibLLVM.create_target_data_layout(self)
               {% end %}
      layout ? TargetData.new(layout) : raise "Missing layout for #{self}"
    end
  end

  def triple
    triple_c = LibLLVM.get_target_machine_triple(self)
    LLVM.string_and_dispose(triple_c)
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
      raise LLVM.string_and_dispose(error_msg)
    end
    true
  end

  def abi
    triple = self.triple
    case triple
    when /x86_64|amd64/
      ABI::X86_64.new(self)
    when /i386|i486|i586|i686/
      ABI::X86.new(self)
    when /aarch64/
      ABI::AArch64.new(self)
    when /arm/
      ABI::ARM.new(self)
    else
      raise "Unsupported ABI for target triple: #{triple}"
    end
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVM.dispose_target_machine(@unwrap)
  end
end
