require "c/sys/file"

# :nodoc:
module Crystal::System::File
  def self.open(filename, mode, perm)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename.check_no_null_byte, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename.inspect_unquoted}' with mode '#{mode}'")
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

    raise Errno.new("mkstemp: '#{path.inspect_unquoted}'") if fd == -1
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
      if {Errno::ENOENT, Errno::ENOTDIR}.includes? Errno.value
        return nil
      else
        raise Errno.new("Unable to get info for '#{path.inspect_unquoted}'")
      end
    end
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
    raise Errno.new("Error changing owner of '#{path.inspect_unquoted}'") if ret == -1
  end

  def self.chmod(path, mode)
    if LibC.chmod(path, mode) == -1
      raise Errno.new("Error changing permissions of '#{path.inspect_unquoted}'")
    end
  end

  def self.delete(path)
    err = LibC.unlink(path.check_no_null_byte)
    if err == -1
      raise Errno.new("Error deleting file '#{path.inspect_unquoted}'")
    end
  end

  def self.real_path(path)
    real_path_ptr = LibC.realpath(path, nil)
    raise Errno.new("Error resolving real path of '#{path.inspect_unquoted}'") unless real_path_ptr
    String.new(real_path_ptr).tap { LibC.free(real_path_ptr.as(Void*)) }
  end

  def self.link(old_path, new_path)
    ret = LibC.link(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating link from '#{old_path.inspect_unquoted}' to '#{new_path.inspect_unquoted}'") if ret != 0
    ret
  end

  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating symlink from '#{old_path.inspect_unquoted}' to '#{new_path.inspect_unquoted}'") if ret != 0
    ret
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      raise Errno.new("Error renaming file '#{old_filename.inspect_unquoted}' to '#{new_filename.inspect_unquoted}'")
    end
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    timevals = uninitialized LibC::Timeval[2]
    timevals[0] = to_timeval(atime)
    timevals[1] = to_timeval(mtime)
    ret = LibC.utimes(filename, timevals)
    if ret != 0
      raise Errno.new("Error setting time on file '#{filename.inspect_unquoted}'")
    end
  end

  private def self.to_timeval(time : ::Time)
    t = uninitialized LibC::Timeval
    t.tv_sec = typeof(t.tv_sec).new(time.to_unix)
    t.tv_usec = typeof(t.tv_usec).new(time.nanosecond / ::Time::NANOSECONDS_PER_MICROSECOND)
    t
  end

  private def system_truncate(size) : Nil
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise Errno.new("Error truncating file '#{path.inspect_unquoted}'")
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

    if LibC.flock(@fd, op) != 0
      raise Errno.new("flock")
    end

    nil
  end

  private def system_fsync(flush_metadata = true) : Nil
    if flush_metadata
      if LibC.fsync(fd) != 0
        raise Errno.new("fsync")
      end
    else
      if LibC.fdatasync(fd) != 0
        raise Errno.new("fdatasync")
      end
    end
  end
end
