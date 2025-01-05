require "../unix/file"

# :nodoc:
module Crystal::System::File
  protected def system_set_mode(mode : String)
  end

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

  def self.delete(path : String, *, raise_on_missing : Bool) : Bool
    raise NotImplementedError.new "Crystal::System::File.delete"
  end
end
