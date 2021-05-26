require "c/sys/file"
require "file/error"

# :nodoc:
module Crystal::System::File
  def self.open(filename, mode, perm)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename.check_no_null_byte, oflag, perm)
    if fd < 0
      raise ::File::Error.from_errno("Error opening file with mode '#{mode}'", file: filename)
    end
    fd
  end

  def self.mktemp(prefix, suffix, dir) : {LibC::Int, String}
    dir = dir + ::File::SEPARATOR
    path = "#{dir}#{prefix}.XXXXXX#{suffix}"

    if suffix
      fd = LibC.mkstemps(path, suffix.bytesize)
    else
      fd = LibC.mkstemp(path)
    end

    raise ::File::Error.from_errno("Error creating temporary file", file: path) if fd == -1
    {fd, path}
  end

  def self.info?(path : String, follow_symlinks : Bool) : ::File::Info?
    stat = uninitialized LibC::Stat
    if follow_symlinks
      ret = LibC.stat(path.check_no_null_byte, pointerof(stat))
    else
      ret = LibC.lstat(path.check_no_null_byte, pointerof(stat))
    end

    if ret == 0
      FileInfo.new(stat)
    else
      if Errno.value.in?(Errno::ENOENT, Errno::ENOTDIR)
        return nil
      else
        raise ::File::Error.from_errno("Unable to get file info", file: path)
      end
    end
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
    ret = if !follow_symlinks && ::File.symlink?(path)
            LibC.lchown(path, uid, gid)
          else
            LibC.chown(path, uid, gid)
          end
    raise ::File::Error.from_errno("Error changing owner", file: path) if ret == -1
  end

  def self.chmod(path, mode)
    if LibC.chmod(path, mode) == -1
      raise ::File::Error.from_errno("Error changing permissions", file: path)
    end
  end

  def self.delete(path)
    err = LibC.unlink(path.check_no_null_byte)
    if err == -1
      raise ::File::Error.from_errno("Error deleting file", file: path)
    end
  end

  def self.real_path(path)
    real_path_ptr = LibC.realpath(path, nil)
    raise ::File::Error.from_errno("Error resolving real path", file: path) unless real_path_ptr
    String.new(real_path_ptr).tap { LibC.free(real_path_ptr.as(Void*)) }
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

  def self.readlink(path) : String
    buf = Bytes.new 256
    # First pass at 256 bytes handles all normal occurrences in 1 system call.
    # Second pass at 1024 bytes handles outliers?
    # Third pass is the max or double what Linux/MacOS can store.
    3.times do |iter|
      bytesize = LibC.readlink(path, buf, buf.bytesize)
      if bytesize == -1
        raise ::File::Error.from_errno("Cannot read link", file: path)
      elsif bytesize == buf.bytesize
        break if iter >= 2
        buf = Bytes.new(buf.bytesize * 4)
      else
        return String.new(buf.to_unsafe, bytesize)
      end
    end

    raise ::File::Error.from_os_error("Cannot read link", Errno::ENAMETOOLONG, file: path)
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      raise ::File::Error.from_errno("Error renaming file", file: old_filename, other: new_filename)
    end
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    timevals = uninitialized LibC::Timeval[2]
    timevals[0] = to_timeval(atime)
    timevals[1] = to_timeval(mtime)
    ret = LibC.utimes(filename, timevals)
    if ret != 0
      raise ::File::Error.from_errno("Error setting time on file", file: filename)
    end
  end

  private def self.to_timeval(time : ::Time)
    t = uninitialized LibC::Timeval
    t.tv_sec = typeof(t.tv_sec).new(time.to_unix)
    t.tv_usec = typeof(t.tv_usec).new(time.nanosecond // ::Time::NANOSECONDS_PER_MICROSECOND)
    t
  end

  private def system_truncate(size) : Nil
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise ::File::Error.from_errno("Error truncating file", file: path)
    end
  end

  private def system_flock_shared(blocking)
    flock LibC::FlockOp::SH, blocking
  end

  private def system_flock_exclusive(blocking)
    flock LibC::FlockOp::EX, blocking
  end

  private def system_flock_unlock
    flock LibC::FlockOp::UN
  end

  private def flock(op : LibC::FlockOp, blocking : Bool = true)
    op |= LibC::FlockOp::NB unless blocking

    if LibC.flock(fd, op) != 0
      raise IO::Error.from_errno("Error applying or removing file lock")
    end

    nil
  end

  private def system_fsync(flush_metadata = true) : Nil
    ret =
      if flush_metadata
        LibC.fsync(fd)
      else
        {% if flag?(:dragonfly) %}
          LibC.fsync(fd)
        {% else %}
          LibC.fdatasync(fd)
        {% end %}
      end

    if ret != 0
      raise IO::Error.from_errno("Error syncing file")
    end
  end
end
