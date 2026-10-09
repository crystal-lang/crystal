struct LLVM::Target
  def self.each(&)
    target = LibLLVM.get_first_target
    while target
      yield Target.new target
      target = LibLLVM.get_next_target target
    end
  end

  def self.first : self
    first? || raise "No LLVM targets available (did you forget to invoke LLVM.init_native_target?)"
  end

  def self.first? : self?
    target = LibLLVM.get_first_target
    target ? Target.new(target) : nil
  end

  def self.from_triple(triple) : self
    return_code = LibLLVM.get_target_from_triple triple, out target, out error
    raise ArgumentError.new(LLVM.string_and_dispose(error)) unless return_code == 0
    new target
  end

  def initialize(@unwrap : LibLLVM::TargetRef)
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
                            code_model = LLVM::CodeModel::Default,
                            emulated_tls = nil,
                            enable_tls_desc = nil) : LLVM::TargetMachine
    target_machine =
      {% if LibLLVM.has_method?(:create_target_machine_options) %}
        begin
          options = LibLLVM.create_target_machine_options
          LibLLVM.target_machine_options_set_cpu(options, cpu)
          LibLLVM.target_machine_options_set_features(options, features)
          LibLLVM.target_machine_options_set_code_gen_opt_level(options, opt_level)
          LibLLVM.target_machine_options_set_code_model(options, code_model)
          LibLLVM.target_machine_options_set_reloc_mode(options, reloc)
          {% if LibLLVM.has_method?(:target_machine_options_set_emulated_tls) %}
            LibLLVM.target_machine_options_set_emulated_tls(options, emulated_tls ? 1 : 0) unless emulated_tls.nil?
            LibLLVM.target_machine_options_set_enable_tls_desc(options, enable_tls_desc ? 1 : 0) unless enable_tls_desc.nil?
          {% end %}
          machine = LibLLVM.create_target_machine_with_options(self, triple, options)
          LibLLVM.dispose_target_machine_options(options)
          machine
        end
      {% else %}
        LibLLVM.create_target_machine(self, triple, cpu, features, opt_level, reloc, code_model)
      {% end %}
    target_machine ? TargetMachine.new(target_machine) : raise "Couldn't create target machine"
  end

  def to_s(io : IO) : Nil
    io << "LLVM::Target(name="
    name.inspect(io)
    io << ", description="
    description.inspect(io)
    io << ')'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def to_unsafe
    @unwrap
  end
end
