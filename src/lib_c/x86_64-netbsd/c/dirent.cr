require "./sys/types"

lib LibC
  struct DIR
    dd_fd : Int
    dd_loc : Long
    dd_size : Long
    dd_buf : Char*
    dd_len : Int
    dd_seek : OffT
    dd_internal : Void*
    dd_flags : Int
    dd_lock : Void*
  end

  DT_UNKNOWN =  0
  DT_DIR     =  4
  DT_LNK     = 10

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
