require "llvm"
require "../program"

module Crystal
  module TargetMachine
    DEFAULT = default_target_machine

    private def self.default_target_machine
      LLVM.init_x86

      target = LLVM::Target.first
      target.create_target_machine(guess_target_triple).not_nil!
    end

    private def self.guess_target_triple
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
      system, version, arch = Program.exec("uname -m -s -r").not_nil!.split

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
