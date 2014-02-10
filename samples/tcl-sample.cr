#!/usr/bin/env bin/crystal --run
require "tcl"

puts "Tcl version: #{Tcl.version}"

i = Tcl::Interpreter.new

# tl = i.all_obj_types
# puts "type list"
# puts tl.to_tcl_s

# tl.raw_each do |obj|
#   name = obj.to_tcl_s
#   type = LibTcl.get_obj_type(name)
#   # TYPES[type.to_i] = name.to_sym
#   puts "#{name} -- #{type.address} -- #{String.new(type.value.name)}"
# end
puts i.types

def obj_info(i, v)
  v.to_tcl(i).tap do |o|
    puts v
    puts "  tcl_s: #{o.to_tcl_s}"
    puts "  type_name: #{o.tcl_type_name}"
    puts "  refCount: #{o.lib_obj.value.refCount}"
    puts "  length: #{o.lib_obj.value.length}"
    puts "  typePtr: #{o.lib_obj.value.typePtr.address}"
  end
end

puts "int: "
obj_info(i, 3)

puts "bool: "
obj_info(i, true)

puts "list: "
obj_info(i, [] of Int32)

puts "string:"
obj_info(i, "lorem")

puts "eval:"
i.eval "puts \"Hello, World!\""
i.eval "set age 42"
i.eval "puts stdout $age"
# i.eval "3"
puts "ok eva"
puts i.raw_result.to_tcl_s

puts "ok"
# puts "lorem".to_tcl(i).value#.tcl_type_name
# puts true.to_tcl(i).tcl_type_name

