require "c/sys/file"
require "file/error"

# :nodoc:
module Crystal::System::File
  def self.open(filename : String, mode : String, perm : Int32 | ::File::Permissions, blocking : Bool?) : {FileDescriptor::Handle, Bool}
    perm = ::File::Permissions.new(perm) if perm.is_a? Int32

    case result = EventLoop.current.open(filename, open_flag(mode), perm, blocking)
    in Tuple(FileDescriptor::Handle, Bool)
      result
    in Errno
      raise ::File::Error.from_os_error("Error opening file with mode '#{mode}'", result, file: filename)
    end
  end

  protected def system_init(mode : String, blocking : Bool) : Nil
  end

  def self.special_type?(fd)
    stat = uninitialized LibC::Stat
    ret = fstat(fd, pointerof(stat))
    # not checking for S_IFSOCK because we can't open(2) a socket
    ret != -1 && (stat.st_mode & LibC::S_IFMT).in?(LibC::S_IFCHR, LibC::S_IFIFO)
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    stat = uninitialized LibC::Stat
    if follow_symlinks
      ret = stat(path.check_no_null_byte, pointerof(stat))
    else
      ret = lstat(path.check_no_null_byte, pointerof(stat))
    end

    if ret == 0
      ::File::Info.new(stat)
    else
      if ::File::NotFoundError.os_error?(Errno.value)
        nil
      else
        raise ::File::Error.from_errno("Unable to get file info", file: path)
      end
    end
  end

  # On some systems, the symbols `stat`, `fstat` and `lstat` are not part of the GNU
  # shared library `libc.so` and instead provided by `libc_noshared.a`.
  # That makes them unavailable for dynamic runtime symbol lookup via `dlsym`
  # which we use for interpreted mode.
  # See https://github.com/crystal-lang/crystal/issues/11157#issuecomment-949640034 for details.
  # Linking against the internal counterparts `__xstat`, `__fxstat` and `__lxstat` directly
  # should work in both interpreted and compiled mode.

  def self.stat(path, stat)
    {% if LibC.has_method?(:__xstat) %}
      LibC.__xstat(LibC::STAT_VER, path, stat)
    {% else %}
      LibC.stat(path, stat)
    {% end %}
  end

  def self.fstat(path, stat)
    {% if LibC.has_method?(:__fxstat) %}
      LibC.__fxstat(LibC::STAT_VER, path, stat)
    {% else %}
      LibC.fstat(path, stat)
    {% end %}
  end

  def self.lstat(path, stat)
    {% if LibC.has_method?(:__lxstat) %}
      LibC.__lxstat(LibC::STAT_VER, path, stat)
    {% else %}
      LibC.lstat(path, stat)
    {% end %}
  end

  def self.info(path, follow_symlinks)
    info?(path, follow_symlinks) || raise ::File::Error.from_errno("Unable to get file info", file: path)
  end

  def self.exists?(path)
    accessible?(path, LibC::F_OK)
  end

  def self.readable?(path) : Bool
    accessible?(path, LibC::R_OK)
  end

  def self.writable?(path) : Bool
    accessible?(path, LibC::W_OK)
  end

  def self.executable?(path) : Bool
    accessible?(path, LibC::X_OK)
  end

  private def self.accessible?(path, flag)
    LibC.access(path.check_no_null_byte, flag) == 0
  end

  def self.chown(path, uid : Int, gid : Int, follow_symlinks)
    ret = if follow_symlinks
            LibC.chown(path, uid, gid)
          else
            LibC.lchown(path, uid, gid)
          end
    raise ::File::Error.from_errno("Error changing owner", file: path) if ret == -1
  end

  def self.fchown(path, fd, uid : Int, gid : Int)
    ret = LibC.fchown(fd, uid, gid)
    raise ::File::Error.from_errno("Error changing owner", file: path) if ret == -1
  end

  def self.chmod(path, mode)
    if LibC.chmod(path, mode) == -1
      raise ::File::Error.from_errno("Error changing permissions", file: path)
    end
  end

  private def system_chmod(path, mode)
    if LibC.fchmod(fd, mode) == -1
      raise ::File::Error.from_errno("Error changing permissions", file: path)
    end
  end

  def self.delete(path, *, raise_on_missing : Bool) : Bool
    err = LibC.unlink(path.check_no_null_byte)
    if err != -1
      true
    elsif !raise_on_missing && ::File::NotFoundError.os_error?(Errno.value)
      false
    else
      raise ::File::Error.from_errno("Error deleting file", file: path)
    end
  end

  def self.realpath(path)
    realpath_ptr = LibC.realpath(path, nil)
    raise ::File::Error.from_errno("Error resolving real path", file: path) unless realpath_ptr
    String.new(realpath_ptr).tap { LibC.free(realpath_ptr.as(Void*)) }
  end

  def self.link(old_path, new_path)
    ret = LibC.link(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise ::File::Error.from_errno("Error creating link", file: old_path, other: new_path) if ret != 0
    ret
  end

  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise ::File::Error.from_errno("Error creating symlink", file: old_path, other: new_path) if ret != 0
    ret
  end

  def self.readlink(path, &) : String
    buf = uninitialized UInt8[4096]
    bytesize = LibC.readlink(path, buf, buf.size)
    if bytesize == -1
      if ::File::NotFoundError.os_error?(Errno.value) || Errno.value == Errno::EINVAL
        yield
      end

      raise ::File::Error.from_errno("Cannot read link", file: path)
    elsif bytesize == buf.size
      raise ::File::Error.from_os_error("Cannot read link", Errno::ENAMETOOLONG, file: path)
    else
      return String.new(buf.to_unsafe, bytesize)
    end
  end

  def self.rename(old_filename, new_filename) : ::File::Error?
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      ::File::Error.from_errno("Error renaming file", file: old_filename, other: new_filename)
    end
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    ret =
      {% if LibC.has_method?("utimensat") %}
        timespecs = uninitialized LibC::Timespec[2]
        timespecs[0] = Crystal::System::Time.to_timespec(atime)
        timespecs[1] = Crystal::System::Time.to_timespec(mtime)
        LibC.utimensat(LibC::AT_FDCWD, filename, timespecs, 0)
      {% else %}
        timevals = uninitialized LibC::Timeval[2]
        timevals[0] = Crystal::System::Time.to_timeval(atime)
        timevals[1] = Crystal::System::Time.to_timeval(mtime)
        LibC.utimes(filename, timevals)
      {% end %}

    if ret != 0
      raise ::File::Error.from_errno("Error setting time on file", file: filename)
    end
  end

  private def system_utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    ret = {% if LibC.has_method?("futimens") %}
            timespecs = uninitialized LibC::Timespec[2]
            timespecs[0] = Crystal::System::Time.to_timespec(atime)
            timespecs[1] = Crystal::System::Time.to_timespec(mtime)
            LibC.futimens(fd, timespecs)
          {% elsif LibC.has_method?("futimes") %}
            timevals = uninitialized LibC::Timeval[2]
            timevals[0] = Crystal::System::Time.to_timeval(atime)
            timevals[1] = Crystal::System::Time.to_timeval(mtime)
            LibC.futimes(fd, timevals)
          {% else %}
            {% raise "Missing futimens & futimes" %}
          {% end %}

    if ret != 0
      raise ::File::Error.from_errno("Error setting time on file", file: filename)
    end
  end

  private def system_truncate(size) : Nil
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise ::File::Error.from_errno("Error truncating file", file: path)
    end
  end
end
