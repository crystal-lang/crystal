require "../unix/file"

# :nodoc:
module Crystal::System::File
  protected def system_init(mode : String, blocking : Bool) : Nil
  end

  def self.chmod(path, mode)
    raise NotImplementedError.new "Crystal::System::File.chmod"
  end

  def self.chown(path, uid : Int, gid : Int, follow_symlinks)
    raise NotImplementedError.new "Crystal::System::File.chown"
  end

  private def system_chown(uid : Int, gid : Int)
    raise NotImplementedError.new "Crystal::System::File#system_chown"
  end
end
