require "./sys/types"
require "./stddef"

lib LibC
  fun dprintf(fd : Int, format : Char*, ...) : Int
  fun printf(format : Char*, ...) : Int
  fun rename(from : Char*, to : Char*) : Int
  fun snprintf(str : Char*, size : SizeT, format : Char*, ...) : Int
end
