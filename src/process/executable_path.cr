# Reference:
# - https://github.com/gpakosz/whereami/blob/master/src/whereami.c
# - http://stackoverflow.com/questions/1023306/finding-current-executables-path-without-proc-self-exe

class Process
  PATH_DELIMITER = {% if flag?(:windows) %} ';' {% else %} ':' {% end %}

  # :nodoc:
  INITIAL_PATH = ENV["PATH"]?

  # :nodoc:
  INITIAL_PWD = Dir.current

  # Returns an absolute path to the executable file of the currently running
  # program. This is in opposition to `PROGRAM_NAME` which may be a relative or
  # absolute path, just the executable file name or a symlink.
  #
  # The executable path will be canonicalized (all symlinks and relative paths
  # will be expanded).
  #
  # Returns `nil` if the file can't be found.
  def self.executable_path
    if executable = executable_path_impl
      begin
        File.real_path(executable)
      rescue Errno
      end
    end
  end

  # Searches an executable, checking for an absolute path, a path relative to
  # *pwd* or absolute path, then eventually searching in directories declared
  # in *path*.
  def self.find_executable(name, path = ENV["PATH"]?, pwd = Dir.current)
    if name.starts_with?(File::SEPARATOR)
      return name
    end

    if name.includes?(File::SEPARATOR)
      return File.expand_path(name, pwd)
    end

    return unless path

    path.split(PATH_DELIMITER).each do |path|
      executable = File.join(path, name)
      return executable if File.exists?(executable)
    end

    nil
  end
end

{% if flag?(:darwin) %}
  lib LibC
    PATH_MAX = 1024
    fun _NSGetExecutablePath(buf : Char*, bufsize : UInt32*) : Int
  end

  class Process
    private def self.executable_path_impl
      buf = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
      size = LibC::PATH_MAX.to_u32

      if LibC._NSGetExecutablePath(buf, pointerof(size)) == -1
        buf = GC.malloc_atomic(size).as(UInt8*)
        return nil if LibC._NSGetExecutablePath(buf, pointerof(size)) == -1
      end

      String.new(buf)
    end
  end
{% elsif flag?(:freebsd) %}
  require "c/sysctl"

  class Process
    private def self.executable_path_impl
      mib = Int32[LibC::CTL_KERN, LibC::KERN_PROC, LibC::KERN_PROC_PATHNAME, -1]
      buf = GC.malloc_atomic(LibC::PATH_MAX).as(UInt8*)
      size = LibC::SizeT.new(LibC::PATH_MAX)

      if LibC.sysctl(mib, 4, buf, pointerof(size), nil, 0) == 0
        String.new(buf, size - 1)
      end
    end
  end
{% elsif flag?(:linux) %}
  class Process
    private def self.executable_path_impl
      "/proc/self/exe"
    end
  end
{% elsif flag?(:win32) %}
  require "c/libloaderapi"

  class Process
    private def self.executable_path_impl
      size = 512_u32
      buf = GC.malloc_atomic(size).as(UInt16*)
      len = LibC.GetModuleFileNameW(LibC::NULL, buf, size)
      if len == 0
        LibC.dprintf 2, "GetModuleFileNameW ERR: #{LibC.GetLastError}\n"
        nil
      else
        String.from_utf16(Slice.new(buf, len))
      end
    end
  end
{% else %}
  # openbsd, ...
  class Process
    private def self.executable_path_impl
      find_executable(PROGRAM_NAME, INITIAL_PATH, INITIAL_PWD)
    end
  end
{% end %}
