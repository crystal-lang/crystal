module Crystal
  class LLVMConfig
    def bin(name)
      "#{bin_dir}/#{name}"
    end

    def llvm_config
      @llvm_config ||= begin
        if system("which llvm-config-3.3 > /dev/null 2>&1") == 0
          "llvm-config-3.3"
        elsif system("which llvm-config > /dev/null 2>&1") == 0
          "llvm-config"
        else
          raise "Couldn't determine llvm-config binary"
        end
      end
    end

    def bin_dir
      @bin_dir ||= Program.exec "#{llvm_config} --bindir"
    end
  end
end
