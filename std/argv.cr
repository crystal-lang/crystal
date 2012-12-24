require "array"
require "int"
require "string"

ARGV = begin
         argv = Array.new(ARGC_UNSAFE - 1)
         (ARGC_UNSAFE - 1).times do |i|
           argv.push String.from_cstr(ARGV_UNSAFE[i + 1])
         end
         argv
       end