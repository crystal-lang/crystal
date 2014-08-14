module Crystal
  class LLVMConfig
    def bin(name)
      if system("which #{name} > /dev/null 2>&1") == 0
        Program.exec("which #{name}").not_nil!
      else
        "#{bin_dir}/#{name}"
      end
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

    def host_target
      @host_target ||= Program.exec("#{llvm_config} --host-target").not_nil!
    end
  end
end
