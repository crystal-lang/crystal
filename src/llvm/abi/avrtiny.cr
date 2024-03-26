require "./avr"

# “Reduced Tiny” Tiny core devices with only 16 general purpose registers.
class LLVM::ABI::AVRTiny < LLVM::ABI::AVR
  def initialize(target_machine : TargetMachine)
    super target_machine
    @rsize = 4 # values above 4 bytes are returned by memory
    @rmin = 20 # 6 registers (R25..R20) for call arguments
  end
end
