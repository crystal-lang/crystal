{% skip_file if flag?(:bsd) %}

require "c/unistd"

module Crystal::System
  def self.cpu_count
    LibC.sysconf(LibC::SC_NPROCESSORS_ONLN)
  end
end
