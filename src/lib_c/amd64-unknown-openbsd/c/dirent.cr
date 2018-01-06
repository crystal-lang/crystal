require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    d_fileno : InoT                         # file number of entry
    d_off : OffT                            # offset after this entry
    d_reclen : UShort                       # length of this record
    d_type : Char                           # file type, see below
    d_namlen : Char                         # length of string in d_name
    __d_padding : StaticArray(Char, 4)      # suppress padding after d_name
    d_name : StaticArray(Char, 256)         # name must be no longer than this
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
