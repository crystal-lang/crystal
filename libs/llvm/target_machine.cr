struct LLVM::TargetMachine
  def initialize(@unwrap)
  end

  def data_layout
    layout = LibLLVM.get_target_machine_data(self)
    layout ? TargetDataLayout.new(layout) : nil
  end
end
