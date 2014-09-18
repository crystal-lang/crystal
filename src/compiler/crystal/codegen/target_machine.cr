require "llvm"
require "../program"

module Crystal
  module TargetMachine
    HOST_TARGET_TRIPLE = guess_host_target_triple

    def self.create(target_triple, cpu, release)
      LLVM.init_x86

      opt_level = release ? LibLLVM::CodeGenOptLevel::Aggressive : LibLLVM::CodeGenOptLevel::None

      target = LLVM::Target.first
      target.create_target_machine(target_triple, cpu: cpu, opt_level: opt_level).not_nil!
    end

    private def self.guess_host_target_triple
      # Some uname -m -s -r samples:
      #
      #   Linux 3.15.3-tinycore64 x86_64
      #   Linux 3.2.0-23-generic-pae i686
      #   Linux 3.2.0-23-generic x86_64
      #   Darwin 13.3.0 x86_64
      #
      # And some triples:
      #
      #   x86_64-pc-linux-gnu
      #   i686-pc-linux-gnu
      #   x86_64-apple-darwin12.3.0
      system, version, arch = `uname -m -s -r`.split

      case system
      when "Darwin"
        if arch == "x86_64"
          "x86_64-apple-darwin#{version}"
        else
          "x86-apple-darwin#{version}"
        end
      when "Linux"
        if arch == "x86_64"
          "x86_64-pc-linux-gnu"
        else
          "i686-pc-linux-gnu"
        end
      else
        raise "Unsupported system: #{system}"
      end
    end
  end
end
