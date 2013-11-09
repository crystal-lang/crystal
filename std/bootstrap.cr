require "int"
require "pointer"
require "array"
require "io"
require "string"
# require "gc"
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
require "crystal/ast"
require "math"
require "nil"
require "number"
require "object"
require "process"
require "range"
require "random"
require "regexp"
require "value"
require "reference"
require "string_builder"
require "symbol"
require "argv"
require "time"
require "exception"
require "errno"
require "raise"
require "tuple"
require "assert"
# require "main"

lib CrystalMain
  fun __crystal_main(argc : Int32, argv : Char**)
end

fun main(argc : Int32, argv : Char**) : Int32
  CrystalMain.__crystal_main(argc, argv)
  0
end

