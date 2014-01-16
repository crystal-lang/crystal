lib C
  type Dir : Void*

  ifdef darwin
    struct DirEntry
      d_ino : Int32
      reclen : UInt16
      type : UInt8
      namelen : UInt8
      name : UInt8
    end
  elsif linux
   struct DirEntry
      d_ino : UInt64
      d_off : Int64
      reclen : UInt16
      type : UInt8
      name : UInt8
    end
  end

  enum DirType
    UNKNOWN = 0_u8
    FIFO = 1_u8
    CHR = 2_u8
    DIR = 4_u8
    BLK = 6_u8
    REG = 8_u8
    LNK = 10_u8
    SOCK = 12_u8
    WHT = 14_u8
  end

  fun getcwd(buffer : UInt8*, size : Int32) : UInt8*
  fun opendir(name : UInt8*) : Dir*
  fun closedir(dir : Dir*) : Int32

  ifdef darwin
    fun readdir(dir : Dir*) : DirEntry*
  elsif linux
    fun readdir = readdir64(dir : Dir*) : DirEntry*
  end
end

class Dir
  def self.working_directory
    dir = C.getcwd(nil, 0)
    String.new(dir)
  end

  def self.list(dirname)
    dir = C.opendir(dirname)
    unless dir
      raise Errno.new("Error listing directory '#{dirname}'")
    end

    begin
      while ent = C.readdir(dir)
        yield String.new(pointerof(ent->name)), ent.value.type
      end
    ensure
      C.closedir(dir)
    end
  end
end
