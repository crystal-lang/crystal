require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    d_fileno : InoT                    # file number of entry
    d_off : OffT                       # offset after this entry
    d_reclen : UShort                  # length of this record
    d_type : Char                      # file type, see below
    d_namlen : Char                    # length of string in d_name
    __d_padding : StaticArray(Char, 4) # suppress padding after d_name
    d_name : StaticArray(Char, 256)    # name must be no longer than this
  end

  fun opendir(filename : Char*) : DIR*
  fun readdir(dirp : DIR*) : Dirent*
  fun rewinddir(dirp : DIR*) : Void
  fun closedir(dirp : DIR*) : Int
end
