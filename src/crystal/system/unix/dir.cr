require "c/dirent"

module Crystal::System::Dir
  def self.open(path : String) : LibC::DIR*
    dir = LibC.opendir(path.check_no_null_byte)
    raise IO::FileSystemError.from_errno("Error opening directory", path) unless dir
    dir
  end

  def self.next_entry(dir) : Entry?
    # LibC.readdir returns NULL and sets errno for failure or returns NULL for EOF but leaves errno as is.
    # This means we need to reset `Errno` before calling `readdir`.
    Errno.value = 0
    if entry = LibC.readdir(dir)
      name = String.new(entry.value.d_name.to_unsafe)
      dir = entry.value.d_type == LibC::DT_DIR
      Entry.new(name, dir)
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
      raise IO::FileSystemError.from_errno("Error while changing directory", path)
    end

    path
  end

  def self.tempdir
    tmpdir = ENV["TMPDIR"]? || "/tmp"
    tmpdir.rchop(::File::SEPARATOR)
  end

  def self.create(path : String, mode : Int32) : Nil
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise IO::FileSystemError.from_errno("Unable to create directory", path)
    end
  end

  def self.delete(path : String) : Nil
    if LibC.rmdir(path.check_no_null_byte) == -1
      raise IO::FileSystemError.from_errno("Unable to remove directory", path)
    end
  end
end
