require "wrapper"

struct LLVM::TargetMachine
  include LLVM::Wrapper

  def initialize(@target_machine)
  end

  def wrapped_pointer
    @target_machine
  end

  def data_layout
    layout = LibLLVM.get_target_machine_data(@target_machine)
    layout ? TargetDataLayout.new(layout) : nil
  end
end
