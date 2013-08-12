require "tcl_tk"

LibTcl.get_version out major, out minor, out patch_level, out type
puts "Version: #{major}.#{minor} (patch level: #{patch_level})"

interp = LibTcl.create_interp
LibTk.init interp
LibTk.main_loop
