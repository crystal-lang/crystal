require "./sys/types"

lib LibC
  type DIR = Void

  DT_DIR = 4

  struct Dirent
    d_fileno : InoT
    d_namlen : UShort
    d_type : UChar
    d_unused1 : UChar
    d_unused2 : UInt
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
