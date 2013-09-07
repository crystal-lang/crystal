require "dl"

module Crystal
  class LLVMConfig
    def self.bin_dir
      @bin_dir ||= begin
        bin_dir = `llvm-config --bindir` rescue nil
        bin_dir ||= `llvm-config-3.3 --bindir` rescue nil
        unless bin_dir
          raise "Couldn't determine llvm bin dir"
        end
        bin_dir.strip
      end
    end

    def self.bin(name)
      "#{bin_dir}/#{name}"
    end
  end
end
