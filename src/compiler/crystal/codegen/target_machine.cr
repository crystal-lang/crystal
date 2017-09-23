require "llvm"
require "../program"

module Crystal
  module TargetMachine
    class Error < Crystal::LocationlessException
    end

    def self.create(target_triple, cpu = "", features = "", release = false) : LLVM::TargetMachine
      case target_triple
      when /^(x86_64|i[3456]86|amd64)/
        LLVM.init_x86
      when /^aarch64/
        LLVM.init_aarch64
      when /^arm/
        LLVM.init_arm

        # Enable most conservative FPU for hard-float capable targets, unless a
        # CPU is defined (it will most certainly enable a better FPU) or
        # features contains a floating-point definition.
        if cpu.empty? && !features.includes?("fp") && target_triple =~ /-gnueabihf/
          features += "+vfp2"
        end
      else
        raise TargetMachine::Error.new("Unsupported architecture for target triple: #{target_triple}")
      end

      opt_level = release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None

      target = LLVM::Target.from_triple(target_triple)
      target.create_target_machine(target_triple, cpu: cpu, features: features, opt_level: opt_level).not_nil!
    end
  end
end
