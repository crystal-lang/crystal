{% skip_file() if flag?(:openbsd) || flag?(:freebsd) %}

require "c/unistd"

module Crystal::System
  def self.cpu_count
    LibC.sysconf(LibC::SC_NPROCESSORS_ONLN)
  end
end
