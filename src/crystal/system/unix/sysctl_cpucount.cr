{% skip_file unless flag?(:bsd) %}

require "c/sysctl"

{% if flag?(:freebsd) %}
  require "c/sys/cpuset"
{% end %}

module Crystal::System
  def self.cpu_count
    mib = Int32[LibC::CTL_HW, LibC::HW_NCPU]
    ncpus = 0
    size = LibC::SizeT.new(sizeof(Int32))

    if LibC.sysctl(mib, 2, pointerof(ncpus), pointerof(size), nil, 0) == 0
      ncpus
    else
      -1
    end
  end

  def self.effective_cpu_count
    {% if flag?(:freebsd) %}
      buffer = uninitialized UInt8[8192]
      maxcpus = 0
      size = LibC::SizeT.new(sizeof(Int32))

      if LibC.sysctlbyname("kern.smp.maxcpus", pointerof(maxcpus), pointerof(size), nil, 0) == 0
        len = ((maxcpus + 7) // 8).clamp(..buffer.size)
        set = buffer.to_slice[0, len]

        if LibC.cpuset_getaffinity(LibC::CPU_LEVEL_WHICH, LibC::CPU_WHICH_PID, -1, len, set) == 0
          return set.sum(&.popcount)
        end
      end
    {% elsif flag?(:netbsd) || flag?(:openbsd) %}
      mib = Int32[LibC::CTL_HW, LibC::HW_NCPUONLINE]
      ncpus = 0
      size = LibC::SizeT.new(sizeof(Int32))

      if LibC.sysctl(mib, 2, pointerof(ncpus), pointerof(size), nil, 0) == 0
        return ncpus
      end
    {% end %}

    -1
  end
end
