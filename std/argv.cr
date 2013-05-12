require "array"
require "int"
require "string"
require "pointer"

ARGV = begin
         argv = Array(String).new(ARGC_UNSAFE - 1)
         argv.length = ARGC_UNSAFE - 1
         (ARGC_UNSAFE - 1).times do |i|
           argv.buffer[i] = String.from_cstr(ARGV_UNSAFE[i + 1])
         end
         argv
       end