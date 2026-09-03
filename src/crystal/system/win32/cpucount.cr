require "c/sysinfoapi"

module Crystal::System
  def self.cpu_count
    LibC.GetNativeSystemInfo(out system_info)
    system_info.dwNumberOfProcessors
  end

  def self.effective_cpu_count
    if LibC.GetProcessAffinityMask(LibC.GetCurrentProcess, out process_affinity, out _) == 0
      -1
    else
      process_affinity.popcount
    end
  end
end
