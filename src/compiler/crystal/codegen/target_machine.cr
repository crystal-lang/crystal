require "llvm"
require "../program"

module Crystal
  module TargetMachine
    def self.create(target_triple, cpu, release) : LLVM::TargetMachine
      case target_triple
      when /^(x86_64|i[3456]86)/
        LLVM.init_x86
      when /^arm/
        LLVM.init_arm
      else
        raise "Unsupported arch for target triple: #{target_triple}"
      end

      opt_level = release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None

      target = LLVM::Target.from_triple(target_triple)
      target.create_target_machine(target_triple, cpu: cpu, opt_level: opt_level).not_nil!
    end
  end
end
