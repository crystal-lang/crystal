lib C
  struct Dir
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

  struct DirEntry
    d_ino : Int32
    reclen : UInt16
    type : UInt8
    namelen : UInt8
    name : Char
  end

  fun getcwd(buffer : Char*, size : Int32) : Char*
  fun opendir(name : Char*) : Dir*
  fun readdir(dir : Dir*) : DirEntry*
  fun closedir(dir : Dir*) : Int32
end

class Dir
  def self.working_directory
    dir = C.getcwd(nil, 0)
    String.new(dir)
  end

  def self.list(dirname)
    dir = C.opendir(dirname)
    raise Errno.new unless dir

    begin
      while ent = C.readdir(dir)
        yield String.new(ent.as(Pointer(Char)) + 8), ent.value.type
      end
    ensure
      C.closedir(dir)
    end
  end
end
