struct LLVM::Target
  def self.first
    Target.new LibLLVM.get_first_target
  end

  def initialize(@unwrap)
  end

  def name
    String.new LibLLVM.get_target_name(self)
  end

  def description
    String.new LibLLVM.get_target_description(self)
  end

  def create_target_machine(triple, cpu = "", features = "",
    opt_level = LibLLVM::CodeGenOptLevel::Default,
    reloc = LibLLVM::RelocMode::Default,
    code_model = LibLLVM::CodeModel::Default)
    target_machine = LibLLVM.create_target_machine(self, triple, cpu, features, opt_level, reloc, code_model)
    target_machine ? TargetMachine.new(target_machine) : nil
  end

  def to_s(io)
    io.append_c_string LibLLVM.get_target_name(self)
    io << " - "
    io.append_c_string LibLLVM.get_target_description(self)
  end
end
