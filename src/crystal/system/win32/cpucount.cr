require "c/sysinfoapi"

module Crystal::System
  def self.cpu_count
    LibC.GetNativeSystemInfo(out system_info)
    system_info.dwNumberOfProcessors
  end

  def self.effective_cpu_count
    -1
  end
end
