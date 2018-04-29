require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    d_ino : UInt64T
    d_off : Int64T
    d_reclen : UShort
    d_type : Char
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
