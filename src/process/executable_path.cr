# Reference:
# - https://github.com/gpakosz/whereami/blob/master/src/whereami.c
# - http://stackoverflow.com/questions/1023306/finding-current-executables-path-without-proc-self-exe

class Process
  {% if flag?(:windows) %}
    PATH_DELIMITER = ';'
  {% else %}
    PATH_DELIMITER = ':'
  {% end %}

  # :nodoc:
  INITIAL_PATH = ENV["PATH"]?

  # :nodoc:
  #
  # Working directory at program start. Nil if working directory does not exist.
  #
  # Used for `Exception::CallStack::CURRENT_DIR`
  # and `Process.executable_path_impl` on openbsd.
  INITIAL_PWD = begin
    Dir.current
  rescue File::NotFoundError
    nil
  end

  # Returns an absolute path to the executable file of the currently running
  # program. This is in opposition to `PROGRAM_NAME` which may be a relative or
  # absolute path, just the executable file name or a symlink.
  #
  # The executable path will be canonicalized (all symlinks and relative paths
  # will be expanded).
  #
  # Returns `nil` if the file can't be found.
  def self.executable_path : String?
    if executable = executable_path_impl
      begin
        File.realpath(executable)
      rescue File::Error
      end
    end
  end

  private def self.file_executable?(path)
    unless File.info?(path, follow_symlinks: true).try &.file?
      return false
    end
    {% if flag?(:win32) %}
      # This is *not* a temporary stub.
      # Windows doesn't have "executable" metadata for files, so it also doesn't have files that are "not executable".
      true
    {% else %}
      File.executable?(path)
    {% end %}
  end

  # Searches an executable, checking for an absolute path, a path relative to
  # *pwd* or absolute path, then eventually searching in directories declared
  # in *path*.
  def self.find_executable(name : Path | String, path : String? = ENV["PATH"]?, pwd : Path | String = Dir.current) : String?
    find_executable_possibilities(Path.new(name), path, pwd) do |p|
      return p.to_s if file_executable?(p)
    end
    nil
  end

  private def self.find_executable_possibilities(name, path, pwd, &)
    return if name.to_s.empty?

    {% if flag?(:win32) %}
      # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw#parameters
      # > If the file name does not contain an extension, .exe is appended.
      # See find_executable_spec.cr for cases this needs to match, based on CreateProcessW behavior.
      basename = name.ends_with_separator? ? "" : name.basename
      basename = "" if basename == name.anchor.to_s
      if (basename.empty? ? !name.anchor : !basename.includes?("."))
        name = Path.new("#{name}.exe")
      end
    {% end %}

    if name.absolute?
      yield name
    end

    # check if the name includes a separator
    count_parts = 0
    name.each_part do
      count_parts += 1
      break if count_parts > 1
    end
    has_separator = (count_parts > 1)

    if {{ flag?(:win32) }} || has_separator
      yield name.expand(pwd)
    end

    if path && !has_separator
      path.split(PATH_DELIMITER).each do |path_entry|
        yield Path.new(path_entry, name)
      end
    end
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
{% elsif flag?(:freebsd) || flag?(:dragonfly) %}
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
{% elsif flag?(:netbsd) %}
  require "c/sysctl"

  class Process
    private def self.executable_path_impl
      mib = Int32[LibC::CTL_KERN, LibC::KERN_PROC_ARGS, -1, LibC::KERN_PROC_PATHNAME]
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
  require "crystal/system/windows"
  require "c/libloaderapi"

  class Process
    private def self.executable_path_impl
      Crystal::System.retry_wstr_buffer do |buffer, small_buf|
        len = LibC.GetModuleFileNameW(nil, buffer, buffer.size)
        if 0 < len < buffer.size
          break String.from_utf16(buffer[0, len])
        elsif small_buf && len == buffer.size
          next 32767 # big enough. 32767 is the maximum total path length of UNC path.
        else
          break nil
        end
      end
    end
  end
{% else %}
  # openbsd, ...
  class Process
    private def self.executable_path_impl
      if pwd = INITIAL_PWD
        find_executable(PROGRAM_NAME, INITIAL_PATH, pwd)
      end
    end
  end
{% end %}
