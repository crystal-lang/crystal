require "./sys/types"
require "./stddef"

lib LibC
  fun printf(x0 : Char*, ...) : Int
  fun dprintf(fd : Int, format : Char*, ...) : Int
  fun rename(x0 : Char*, x1 : Char*) : Int
  fun snprintf(x0 : Char*, x1 : SizeT, x2 : Char*, ...) : Int
end
