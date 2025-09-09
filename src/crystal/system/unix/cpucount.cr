{% if flag?(:bsd) %}
  require "c/sysctl"
{% else %}
  require "c/unistd"
{% end %}
require "./syscall"

module Crystal::System
  def self.cpu_count
    {% if flag?(:bsd) %}
      mib = Int32[LibC::CTL_HW, LibC::HW_NCPU]
      ncpus = 0
      size = sizeof(Int32).to_u64
      if LibC.sysctl(mib, 2, pointerof(ncpus), pointerof(size), nil, 0) == 0
        ncpus
      else
        -1
      end
    {% else %}
      LibC.sysconf(LibC::SC_NPROCESSORS_ONLN)
    {% end %}
  end

  def self.effective_cpu_count
    {% if flag?(:linux) %}
      # we use the syscall because it returns the number of bytes to check in
      # the set, while glibc always returns 0 and would require to zero the
      # buffer and check every byte
      set = uninitialized UInt8[8192] # allows up to 65536 logical cpus
      byte_count = Syscall.sched_getaffinity(0, LibC::SizeT.new(8192), set.to_unsafe)
      if byte_count > 0
        count = set.to_slice[0, byte_count].sum(&.popcount)
        return count if count > 0
      end
    {% end %}

    -1
  end
end
