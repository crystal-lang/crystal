require "./sys/types"

lib LibC
  type DIR = Void

  DT_UNKNOWN =  0
  DT_DIR     =  4
  DT_LNK     = 10

  struct Dirent
    d_fileno : InoT
    d_off : OffT
    d_reclen : UShort
    d_type : Char
    d_namlen : Char
    __d_padding : StaticArray(Char, 4)
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
  fun dirfd(dirp : DIR*) : Int
end
