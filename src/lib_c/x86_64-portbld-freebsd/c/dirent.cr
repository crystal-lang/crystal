require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    {% if flag?(:"freebsd12.0") %}
      d_fileno : ULong
      d_off : ULong
    {% else %}
      d_fileno : UInt
    {% end %}
    d_reclen : UShort
    d_type : UChar
    {% if flag?(:"freebsd12.0") %}
      d_pad0 : UChar
      d_namlen : UShort
      d_pad1 : UShort
    {% else %}
      d_namlen : UChar
    {% end %}
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
