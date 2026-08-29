{% skip_file unless flag?(:linux) %}

require "./syscall"

module Crystal::System
  def self.effective_cpu_count
    {% unless flag?(:interpreted) %}
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
