class LLVM::TargetMachine
  def initialize(@target_machine)
  end

  def data_layout
    layout = LibLLVM.get_target_machine_data(@target_machine)
    layout ? TargetDataLayout.new(layout) : nil
  end
end
