require "array"
require "bool"
require "c"
require "char"
require "comparable"
require "enumerable"
require "env"
require "file"
require "float"
require "hash"
require "int"
require "io"
require "macro"
require "math"
require "nil"
require "numeric"
require "object"
require "pointer"
require "range"
require "regexp"
require "reference"
require "string"
require "string_builder"
require "symbol"
require "argv"
require "time"

def raise(msg)
  print "ERROR: "
  print msg.to_s
  puts

  exit 1
end
