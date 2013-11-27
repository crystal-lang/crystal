lib C
 struct DirEntry
    d_ino : UInt64
    reclen : Int64
    type : UInt16
    namelen : UInt8
    name : Char
  end
end

class Dir
  def self.dir_entry_offset
    19
  end
end
