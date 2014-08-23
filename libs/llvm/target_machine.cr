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

  def to_unsafe
    @unwrap
  end
end
