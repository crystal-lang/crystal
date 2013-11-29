lib C
 struct DirEntry
    d_ino : UInt64
    d_off : Int64
    reclen : UInt16
    type : UInt8
    name : Char
  end
end

class Dir
  def self.dir_entry_offset
    19
  end
end
