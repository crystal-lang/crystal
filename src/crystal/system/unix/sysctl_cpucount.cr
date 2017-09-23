{% skip_file() unless flag?(:openbsd) || flag?(:freebsd) %}

require "c/sysctl"

module Crystal::System
  def self.cpu_count
    mib = Int32[LibC::CTL_HW, LibC::HW_NCPU]
    ncpus = 0
    size = sizeof(Int32).to_u64

    if LibC.sysctl(mib, 2, pointerof(ncpus), pointerof(size), nil, 0) == 0
      ncpus
    else
      -1
    end
  end
end
