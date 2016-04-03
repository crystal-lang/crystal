# This is a small sample on how to use a Crystal's
# formatter programmatically.

# Use `require "compiler/crystal/formatter"` in your programs
require "../../src/compiler/crystal/formatter"

source = "[ 1 , 2 , 3].map { | x |  x.to_s  }"
result = Crystal.format(source)
puts result
