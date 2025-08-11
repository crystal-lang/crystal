require "c/dirent"

module Crystal::System::Dir
  def self.open(path : String) : LibC::DIR*
    dir = LibC.opendir(path.check_no_null_byte)
    raise ::File::Error.from_errno("Error opening directory", file: path) unless dir
    dir
  end

  def self.next_entry(dir, path) : Entry?
    # LibC.readdir returns NULL and sets errno for failure or returns NULL for EOF but leaves errno as is.
    # This means we need to reset `Errno` before calling `readdir`.
    Errno.value = Errno::NONE
    if entry = LibC.readdir(dir)
      name = String.new(entry.value.d_name.to_unsafe)

      dir =
        {% if flag?(:solaris) %}
          # `d_type` is a Linux / BSD extension
          nil
        {% else %}
          case entry.value.d_type
          when LibC::DT_DIR                   then true
          when LibC::DT_UNKNOWN, LibC::DT_LNK then nil
          else                                     false
          end
        {% end %}

      # TODO: support `st_flags & UF_HIDDEN` on BSD-like systems: https://man.freebsd.org/cgi/man.cgi?query=stat&sektion=2
      # TODO: support hidden file attributes on macOS / HFS+: https://stackoverflow.com/a/15236292
      # (are these the same?)
      Entry.new(name, dir, false)
    elsif Errno.value != Errno::NONE
      raise ::File::Error.from_errno("Error reading directory entries", file: path)
    else
      nil
    end
  end

  def self.rewind(dir) : Nil
    LibC.rewinddir(dir)
  end

  def self.info(dir, path) : ::File::Info
    fd = {% if flag?(:netbsd) %}
           dir.value.dd_fd
         {% else %}
           LibC.dirfd(dir)
         {% end %}
    Crystal::System::FileDescriptor.system_info(fd)
  end

  def self.close(dir, path) : Nil
    if LibC.closedir(dir) != 0
      raise ::File::Error.from_errno("Error closing directory", file: path)
    end
  end

  def self.current : String
    # If $PWD is set and it matches the current path, use that.
    # This helps telling apart symlinked paths.
    if (pwd = ENV["PWD"]?) && pwd.starts_with?("/") &&
       (pwd_info = ::Crystal::System::File.info?(pwd, follow_symlinks: true)) &&
       (dot_info = ::Crystal::System::File.info?(".", follow_symlinks: true)) &&
       pwd_info.same_file?(dot_info)
      return pwd
    end

    unless dir = LibC.getcwd(nil, 0)
      raise ::File::Error.from_errno("Error getting current directory", file: "./")
    end

    dir_str = String.new(dir)
    LibC.free(dir.as(Void*))
    dir_str
  end

  def self.current=(path : String)
    if LibC.chdir(path.check_no_null_byte) != 0
      raise ::File::Error.from_errno("Error while changing directory", file: path)
    end

    path
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise ::File::Error.from_errno("Unable to create directory", file: path)
    end
  end

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    return true if LibC.rmdir(path.check_no_null_byte) == 0

    if !raise_on_missing && Errno.value == Errno::ENOENT
      false
    else
      raise ::File::Error.from_errno("Unable to remove directory", file: path)
    end
  end
end
