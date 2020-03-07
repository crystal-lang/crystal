require "./sys/types"

lib LibC
  type DIR = Void

  DT_DIR = 4

  struct Dirent
    d_fileno : InoT
    d_reclen : UInt16
    d_namlen : UInt16
    d_type : UInt8
    d_name : StaticArray(Char, 512)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir = __opendir30(x0 : Char*) : DIR*
  fun readdir = __readdir30(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
