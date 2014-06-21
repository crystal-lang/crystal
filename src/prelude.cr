require "intrinsics"
require "c"
require "gc"
# require "gc/null"
require "gc/boehm"
require "int"
require "pointer"
require "static_array"
require "array"
require "io"
require "string"
require "bool"
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
require "process"
require "range"
require "random"
require "regex"
require "value"
require "reference"
require "struct"
require "string_builder"
require "symbol"
require "argv"
require "time"
require "exception"
require "errno"
require "raise"
require "tuple"
require "assert"
require "main"

class Class
  def inspect
    to_s
  end
end

def loop
  while true
    yield
  end
end
