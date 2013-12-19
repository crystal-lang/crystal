require "dir.linux" if linux
require "dir.darwin" if darwin

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

  fun getcwd(buffer : Char*, size : Int32) : Char*
  fun opendir(name : Char*) : Dir*
  fun closedir(dir : Dir*) : Int32
end

require "readdir.linux" if linux
require "readdir.darwin" if darwin

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
        yield String.new(ent.as(Pointer(Char)) + dir_entry_offset), ent.value.type
      end
    ensure
      C.closedir(dir)
    end
  end
end
