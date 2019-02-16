require "./sys/types"

lib LibC
  type DIR = Void

  struct Dirent
    {% if flag?(:freebsd11) %}
      d_fileno : UInt
    {% else %}
      d_fileno : ULong
      d_off : ULong
    {% end %}
    d_reclen : UShort
    d_type : UChar
    {% if flag?(:freebsd11) %}
      d_namlen : UChar
    {% else %}
      d_pad0 : UChar
      d_namlen : UShort
      d_pad1 : UShort
    {% end %}
    d_name : StaticArray(Char, 256)
  end

  fun closedir(x0 : DIR*) : Int
  fun opendir(x0 : Char*) : DIR*
  fun readdir(x0 : DIR*) : Dirent*
  fun rewinddir(x0 : DIR*) : Void
end
