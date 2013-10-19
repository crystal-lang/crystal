require "int"
require "pointer"
require "array"
require "io"
require "string"
require "bool"
require "c"
require "char"
require "comparable"
require "enumerable"
require "env"
require "file"
require "dir"
require "float"
require "hash"
require "math"
require "nil"
require "number"
require "object"
# require "process"

lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  0
end

