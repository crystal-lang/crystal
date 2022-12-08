require "../unix/file"

# :nodoc:
module Crystal::System::File
  def self.chmod(path, mode)
    raise NotImplementedError.new "Crystal::System::File.chmod"
  end

  def self.chown(path, uid : Int, gid : Int, follow_symlinks)
    raise NotImplementedError.new "Crystal::System::File.chown"
  end

  def self.realpath(path)
    raise NotImplementedError.new "Crystal::System::File.realpath"
  end

  def self.utime(atime : ::Time, mtime : ::Time, filename : String) : Nil
    raise NotImplementedError.new "Crystal::System::File.utime"
  end

  private def system_flock_shared(blocking)
    raise NotImplementedError.new "Crystal::System::File#system_flock_shared"
  end

  private def system_flock_exclusive(blocking)
    raise NotImplementedError.new "Crystal::System::File#system_flock_exclusive"
  end

  private def system_flock_unlock
    raise NotImplementedError.new "Crystal::System::File#system_flock_unlock"
  end

  private def flock(op : LibC::FlockOp, blocking : Bool = true)
    raise NotImplementedError.new "Crystal::System::File#flock"
  end

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    raise NotImplementedError.new "Crystal::System::File.delete"
  end
end
