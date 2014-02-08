#!/usr/bin/env bin/crystal --run
require "tcl"

puts "Tcl version: #{Tcl.version}"

i = Tcl::Interpreter.new

puts "int: "
puts 3.to_tcl(i).to_tcl_s
puts 3.to_tcl(i).tcl_type_name

puts "bool: "
puts true.to_tcl(i).to_tcl_s
puts true.to_tcl(i).tcl_type_name

puts "list: "
puts ([] of Int32).to_tcl(i).to_tcl_s
puts ([] of Int32).to_tcl(i).tcl_type_name

s = i.create_obj("lorem")
puts "string:"
puts s.to_tcl_s
puts s.tcl_type_name

tl = i.all_obj_types
puts "type list"
puts tl.to_tcl_s

puts "ok"
# puts "lorem".to_tcl(i).value#.tcl_type_name
# puts true.to_tcl(i).tcl_type_name

