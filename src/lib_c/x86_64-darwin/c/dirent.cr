require "./sys/types"

lib LibC
  type DIR = Void

  DT_DIR = 4

  struct Dirent
    d_ino : InoT
    d_seekoff : UInt64
    d_reclen : UShort
    d_namlen : UShort
    d_type : UChar
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir = "opendir$INODE64"(x0 : Char*) : DIR*
  fun readdir = "readdir$INODE64"(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
