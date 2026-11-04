require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    d_ino : UInt64
    d_type : UInt8
    d_name : StaticArray(Char, 0)
  end

  DT_UNKNOWN = 0
  DT_DIR     = 3
  DT_LNK     = 7

  fun opendir(path : Char*) : DIR*
  fun readdir(dir : DIR*) : Dirent*
  fun rewinddir(dir : DIR*) : Void
  fun dirfd(dir : DIR*) : Int
  fun closedir(dir : DIR*) : Int
end
