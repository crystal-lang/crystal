require "c/ntsysteminfo"

module Crystal::System
  def self.cpu_count
    LibC.NTGetSystemInfo(out system_info)
    system_info.dwNumberOfProcessors
  end
end
