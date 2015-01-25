require "llvm"
require "../program"

module Crystal
  module TargetMachine
    def self.create(target_triple, cpu, release)
      LLVM.init_x86

      opt_level = release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None

      target = LLVM::Target.from_triple(target_triple)
      target.create_target_machine(target_triple, cpu: cpu, opt_level: opt_level).not_nil!
    end
  end
end
