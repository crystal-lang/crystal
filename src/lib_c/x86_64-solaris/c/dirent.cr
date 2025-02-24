require "./sys/types"

lib LibC
  struct DIR
    d_fd : Int
    d_loc : Int
    d_size : Int
    d_buf : Char*
  end

  struct Dirent
    d_ino : InoT
    d_off : OffT
    d_reclen : UShort
    d_name : StaticArray(Char, 1)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
  fun dirfd(dirp : DIR*) : Int
end
