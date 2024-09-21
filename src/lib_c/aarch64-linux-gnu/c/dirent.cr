require "./sys/types"

lib LibC
  type DIR = Void

  DT_UNKNOWN =  0
  DT_DIR     =  4
  DT_LNK     = 10

  struct Dirent
    d_ino : InoT
    d_off : OffT
    d_reclen : UShort
    d_type : UChar
    d_name : StaticArray(Char, 256)
  end

  fun closedir(dirp : DIR*) : Int
  fun opendir(name : Char*) : DIR*
  fun readdir(dirp : DIR*) : Dirent*
  fun rewinddir(dirp : DIR*) : Void
  fun dirfd(dirp : DIR*) : Int
end
