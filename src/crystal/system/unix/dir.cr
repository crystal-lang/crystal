require "c/dirent"

module Crystal::System::Dir
  def self.open(path : String) : LibC::DIR*
    dir = LibC.opendir(path.check_no_null_byte)
    raise Errno.new("Error opening directory '#{path.inspect_unquoted}'") unless dir
    dir
  end

  def self.next(dir) : String?
    # LibC.readdir returns NULL and sets errno for failure or returns NULL for EOF but leaves errno as is.
    # This means we need to reset `Errno` before calling `readdir`.
    Errno.value = 0
    if entry = LibC.readdir(dir)
      String.new(entry.value.d_name.to_unsafe)
    elsif Errno.value != 0
      raise Errno.new("readdir")
    else
      nil
    end
  end

  def self.rewind(dir) : Nil
    LibC.rewinddir(dir)
  end

  def self.close(dir) : Nil
    if LibC.closedir(dir) != 0
      raise Errno.new("closedir")
    end
  end

  def self.current : String
    unless dir = LibC.getcwd(nil, 0)
      raise Errno.new("getcwd")
    end

    dir_str = String.new(dir)
    LibC.free(dir.as(Void*))
    dir_str
  end

  def self.current=(path : String)
    if LibC.chdir(path.check_no_null_byte) != 0
      raise Errno.new("Error while changing directory to '#{path.inspect_unquoted}'")
    end

    path
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise Errno.new("Unable to create directory '#{path.inspect_unquoted}'")
    end
  end

  def self.delete(path : String) : Nil
    if LibC.rmdir(path.check_no_null_byte) == -1
      raise Errno.new("Unable to remove directory '#{path.inspect_unquoted}'")
    end
  end
end
