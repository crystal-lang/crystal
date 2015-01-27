require "tcl_tk"

LibTcl.get_version out major, out minor, out patch_level, out type
puts "Version: #{major}.#{minor} (patch level: #{patch_level})"

win = Tk::Window.new
# win.interpreter.eval "PopupMessage \"Hello, World!\""
# win.interpreter.eval "label .l -text \"Hello, World\""
# win.interpreter.eval "pack .l"

label = Tk::Label.new(win, "1")
label.text = "Hello, World"
label.pack

v = Tcl::StringObj.new
puts v.value
v.value = "FooBar"
puts v.value

var = Tcl::StringVar.new(win.interpreter)
# puts var.value
var.value = "FooBar2"
puts var.value

var2 = Tcl::StringVar.new(win.interpreter)
# puts var2.value
var2.value = "FooBar2!"
puts var2.value
puts var.value

# win.main_loop
# C.getchar
