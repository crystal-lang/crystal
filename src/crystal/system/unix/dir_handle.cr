require "c/dirent"
require "c/unistd"
require "c/sys/stat"

class Crystal::System::DirHandle
  @dirhandle : LibC::DIR*

  @closed = false

  def initialize(path : String)
    @dirhandle = LibC.opendir(path.check_no_null_byte)
    unless @dirhandle
      raise Errno.new("Error opening directory '#{path}'")
    end
    @closed = false
  end

  def read
    # readdir() returns NULL for failure and sets errno or returns NULL for EOF but leaves errno as is.  wtf.
    Errno.value = 0
    ent = LibC.readdir(@dirhandle)
    if ent
      String.new(ent.value.d_name.to_unsafe)
    elsif Errno.value != 0
      raise Errno.new("readdir")
    else
      nil
    end
  end

  def rewind
    LibC.rewinddir(@dirhandle)
  end

  def close
    return if @closed
    if LibC.closedir(@dirhandle) != 0
      raise Errno.new("closedir")
    end
    @closed = true
  end

  def self.current : String
    if dir = LibC.getcwd(nil, 0)
      String.new(dir).tap { LibC.free(dir.as(Void*)) }
    else
      raise Errno.new("getcwd")
    end
  end

  def self.cd(path : String)
    if LibC.chdir(path.check_no_null_byte) != 0
      raise Errno.new("Error while changing directory to #{path.inspect}")
    end
  end

  def self.exists?(path : String) : Bool
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT || Errno.value == Errno::ENOTDIR
        return false
      else
        raise Errno.new("stat")
      end
    end
    File::Stat.new(stat).directory?
  end

  def self.mkdir(path : String, mode)
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise Errno.new("Unable to create directory '#{path}'")
    end
  end

  def self.rmdir(path : String)
    if LibC.rmdir(path.check_no_null_byte) == -1
      raise Errno.new("Unable to remove directory '#{path}'")
    end
  end
end
