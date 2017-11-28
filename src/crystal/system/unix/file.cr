require "c/sys/file"

# :nodoc:
module Crystal::System::File
  def self.open(filename, mode, perm)
    oflag = open_flag(mode) | LibC::O_CLOEXEC

    fd = LibC.open(filename.check_no_null_byte, oflag, perm)
    if fd < 0
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end
    fd
  end

  private def self.open_flag(mode)
    if mode.size == 0
      raise "Invalid access mode #{mode}"
    end

    m = 0
    o = 0
    case mode[0]
    when 'r'
      m = LibC::O_RDONLY
    when 'w'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_TRUNC
    when 'a'
      m = LibC::O_WRONLY
      o = LibC::O_CREAT | LibC::O_APPEND
    else
      raise "Invalid access mode #{mode}"
    end

    case mode.size
    when 1
      # Nothing
    when 2
      case mode[1]
      when '+'
        m = LibC::O_RDWR
      when 'b'
        # Nothing
      else
        raise "Invalid access mode #{mode}"
      end
    else
      raise "Invalid access mode #{mode}"
    end

    oflag = m | o
  end

  def self.mktemp(name, extension)
    tmpdir = tempdir + ::File::SEPARATOR
    path = "#{tmpdir}#{name}.XXXXXX#{extension}"

    if extension
      fd = LibC.mkstemps(path, extension.bytesize)
    else
      fd = LibC.mkstemp(path)
    end

    raise Errno.new("mkstemp") if fd == -1
    {fd, path}
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.stat(path)
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      raise Errno.new("Unable to get stat for '#{path}'")
    end
    ::File::Stat.new(stat)
  end

  def self.lstat(path)
    if LibC.lstat(path.check_no_null_byte, out stat) != 0
      raise Errno.new("Unable to get lstat for '#{path}'")
    end
    ::File::Stat.new(stat)
  end

  def self.empty?(path)
    begin
      stat(path).size == 0
    rescue Errno
      raise Errno.new("Error determining size of '#{path}'")
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

  def self.file?(path) : Bool
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    ::File::Stat.new(stat).file?
  end

  def self.chown(path, uid : Int, gid : Int, follow_symlinks)
    ret = if !follow_symlinks && symlink?(path)
            LibC.lchown(path, uid, gid)
          else
            LibC.chown(path, uid, gid)
          end
    raise Errno.new("Error changing owner of '#{path}'") if ret == -1
  end

  def self.chmod(path, mode : Int)
    if LibC.chmod(path, mode) == -1
      raise Errno.new("Error changing permissions of '#{path}'")
    end
  end

  def self.delete(path)
    err = LibC.unlink(path.check_no_null_byte)
    if err == -1
      raise Errno.new("Error deleting file '#{path}'")
    end
  end

  def self.real_path(path)
    real_path_ptr = LibC.realpath(path, nil)
    raise Errno.new("Error resolving real path of #{path}") unless real_path_ptr
    String.new(real_path_ptr).tap { LibC.free(real_path_ptr.as(Void*)) }
  end

  def self.link(old_path, new_path)
    ret = LibC.link(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating link from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  def self.symlink(old_path, new_path)
    ret = LibC.symlink(old_path.check_no_null_byte, new_path.check_no_null_byte)
    raise Errno.new("Error creating symlink from #{old_path} to #{new_path}") if ret != 0
    ret
  end

  def self.symlink?(path)
    if LibC.lstat(path.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    (stat.st_mode & LibC::S_IFMT) == LibC::S_IFLNK
  end

  def self.rename(old_filename, new_filename)
    code = LibC.rename(old_filename.check_no_null_byte, new_filename.check_no_null_byte)
    if code != 0
      raise Errno.new("Error renaming file '#{old_filename}' to '#{new_filename}'")
    end
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    timevals = uninitialized LibC::Timeval[2]
    timevals[0] = to_timeval(atime)
    timevals[1] = to_timeval(mtime)
    ret = LibC.utimes(filename, timevals)
    if ret != 0
      raise Errno.new("Error setting time to file '#{filename}'")
    end
  end

  private def self.to_timeval(time : ::Time)
    t = uninitialized LibC::Timeval
    t.tv_sec = typeof(t.tv_sec).new(time.to_local.epoch)
    t.tv_usec = typeof(t.tv_usec).new(0)
    t
  end

  private def system_truncate(size) : Nil
    flush
    code = LibC.ftruncate(fd, size)
    if code != 0
      raise Errno.new("Error truncating file '#{path}'")
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
end
