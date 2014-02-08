#!/usr/bin/env bin/crystal --run
require "tcl"

puts "Tcl version: #{Tcl.version}"

i = Tcl::Interpreter.new
puts i

