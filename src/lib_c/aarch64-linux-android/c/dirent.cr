require "./sys/types"

lib LibC
  type DIR = Void

  DT_UNKNOWN =  0
  DT_DIR     =  4
  DT_LNK     = 10

  struct Dirent
    d_ino : InoT
    d_off : Long
    d_reclen : UShort
    d_type : UChar
    d_name : StaticArray(Char, 256)
  end

  fun closedir(__dir : DIR*) : Int
  fun opendir(__path : Char*) : DIR*
  fun readdir(__dir : DIR*) : Dirent*
  fun rewinddir(__dir : DIR*)
  fun dirfd(__dir : DIR*) : Int
end
