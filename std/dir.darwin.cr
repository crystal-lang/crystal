lib C
  struct DirEntry
    d_ino : Int32
    reclen : UInt16
    type : UInt8
    namelen : UInt8
    name : Char
  end
end

class Dir
  def self.dir_entry_offset
    8
  end
end
