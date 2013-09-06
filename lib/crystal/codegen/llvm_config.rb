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

    def self.lib_dir
      @lib_dir ||= begin
        lib_dir = `llvm-config --libdir` rescue nil
        lib_dir ||= `llvm-config-3.3 --libdir` rescue nil
        unless lib_dir
          raise "Couldn't determine llvm lib dir"
        end
        lib_dir.strip
      end
    end

    def self.dlopen
      if RUBY_PLATFORM =~ /darwin/
        DL.dlopen "#{LLVMConfig.lib_dir}/libLLVM-3.3.dylib"
      else
        DL.dlopen "#{LLVMConfig.lib_dir}/libLLVM-3.3.so"
      end
    end

    def self.bin(name)
      "#{bin_dir}/#{name}"
    end
  end
end
