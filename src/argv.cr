require "array"
require "int"
require "string"
require "pointer"

ARGV = (ARGV_UNSAFE + 1).map(ARGC_UNSAFE - 1) { |c_str| String.new(c_str) }
