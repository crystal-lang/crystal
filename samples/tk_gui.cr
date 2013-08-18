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

win.main_loop
C.getchar
