require "c/sysctl"

module System
  # nodoc
  class Process
    def self.executable_path_impl
      mib = Int32[LibC::CTL_KERN, LibC::KERN_PROC, LibC::KERN_PROC_PATHNAME, -1]
      buf = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
      size = LibC::SizeT.new(LibC::PATH_MAX)

      if LibC.sysctl(mib, 4, buf, pointerof(size), nil, 0) == 0
        String.new(buf, size - 1)
      end
    end
  end
end
