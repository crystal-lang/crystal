require "../unix/file"

# :nodoc:
module Crystal::System::File
  {% unless flag?(:wasip1) %}
    def self.stat(path, stat)
      # WASI libc's metadata hash for a symlink does not follow the link,
      # even though the rest of stat's metadata does. Resolve the path first
      # so st_ino identifies the target as well.
      resolved = LibC.realpath(path, nil)
      return -1 unless resolved

      begin
        LibC.stat(resolved, stat)
      ensure
        LibC.free(resolved.as(Void*))
      end
    end
  {% end %}

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
