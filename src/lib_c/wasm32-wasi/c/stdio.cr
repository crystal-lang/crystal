require "./sys/types"
require "./stddef"

lib LibC
  fun dprintf(x0 : Int, x1 : Char*, ...) : Int
  fun printf(x0 : Char*, ...) : Int
  fun rename(x0 : Char*, x1 : Char*) : Int
  fun snprintf(x0 : Char*, x1 : SizeT, x2 : Char*, ...) : Int
end
