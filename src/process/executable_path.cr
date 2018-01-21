# Reference:
# - https://github.com/gpakosz/whereami/blob/master/src/whereami.c
# - http://stackoverflow.com/questions/1023306/finding-current-executables-path-without-proc-self-exe

require "crystal/system/process"

class Process
  PATH_DELIMITER = {% if flag?(:windows) %} ';' {% else %} ':' {% end %}

  # Returns an absolute path to the executable file of the currently running
  # program. This is in opposition to `PROGRAM_NAME` which may be a relative or
  # absolute path, just the executable file name or a symlink.
  #
  # The executable path will be canonicalized (all symlinks and relative paths
  # will be expanded).
  #
  # Returns `nil` if the file can't be found.
  def self.executable_path
    if executable = System::Process.executable_path_impl
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
