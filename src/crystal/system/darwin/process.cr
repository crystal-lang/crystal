require "c/mach-o/dyld"

module System
  # nodoc
  class Process
    def self.executable_path_impl
      buf = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
      size = LibC::PATH_MAX.to_u32

      if LibC._NSGetExecutablePath(buf, pointerof(size)) == -1
        buf = GC.malloc_atomic(size).as(UInt8*)
        return nil if LibC._NSGetExecutablePath(buf, pointerof(size)) == -1
      end

      String.new(buf)
    end
  end
end
