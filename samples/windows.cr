# (work in progress)
#
# Compile (in linux or mac) with:
#
#     --prelude=empty --single-module --cross-compile="windows x86"
#
# and then compile with clang on Windows from a VisualC++ command prompt:
#
#     clang-cl windows.bc msvcrt.lib
#
# This generates windows.exe

require "intrinsics"
require "c"
require "macros"
require "object"
require "reference"
# require "exception"
require "value"
require "struct"
require "function"
# require "thread"
require "gc"
require "gc/null"
# require "gc/boehm"
require "class"
require "comparable"
require "nil"
require "bool"
require "char"
require "number"
require "int"
require "float"
require "enumerable"
require "pointer"
require "slice"
require "range"
require "char_reader"
require "string"
require "symbol"
require "static_array"
require "array"
require "hash"
require "set"
require "tuple"
require "box"
require "math"
# require "process"
require "io"
require "argv"
# require "env"
# require "exec"
# require "file"
# require "dir"
# require "time"
require "random"
# require "regex"
# require "raise"
# require "errno"
# require "main"

lib C
  fun exit(status : Int32) : NoReturn
end

class Exception
  getter message
  getter cause
  getter backtrace

  def initialize(message = nil : String?, cause = nil : Exception?)
    @message = message
    @cause = cause
    # @backtrace = caller
  end
end

class EmptyEnumerable < Exception
  def initialize(message = "Empty enumerable")
    super(message)
  end
end

class IndexOutOfBounds < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

class MissingKey < Exception
end

class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end

def raise(message : String)
  raise Exception.new(message)
end

def raise(ex : Exception)
  if msg = ex.message
    puts msg
  end

  C.exit(1)
end

rand(1..10).times do |i|
  puts "Hello Windows #{i}!"
end
