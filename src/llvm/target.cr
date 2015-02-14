struct LLVM::Target
  def self.each
    target = LibLLVM.get_first_target
    while target
      yield Target.new target
      target = LibLLVM.get_next_target target
    end
  end

  def self.first
    Target.new LibLLVM.get_first_target
  end

  def self.from_triple(triple)
    return_code = LibLLVM.get_target_from_triple triple, out target, out error
    raise String.new(error) unless return_code == 0
    new target
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
      opt_level = LLVM::CodeGenOptLevel::Default,
      reloc = LLVM::RelocMode::PIC,
      code_model = LLVM::CodeModel::Default)
    target_machine = LibLLVM.create_target_machine(self, triple, cpu, features, opt_level, reloc, code_model)
    target_machine ? TargetMachine.new(target_machine) : nil
  end

  def to_s(io)
    io << name
    io << " - "
    io << description
  end

  def to_unsafe
    @unwrap
  end
end
