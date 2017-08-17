module System
  # nodoc
  class Process
    def self.executable_path_impl
      "/proc/self/exe"
    end
  end
end
