lib LibTcl("tcl")
  struct Interp
  end

  struct AppInitProc
  end

  fun get_version = Tcl_GetVersion(major : Int32*, minor : Int32*, patch_level : Int32*, type : Void*)
  fun create_interp = Tcl_CreateInterp() : Interp*
  fun eval = Tcl_Eval(interp : Interp*, code : Char*) : Int32
end

lib LibTk("tk")
  fun init = Tk_Init(interp : LibTcl::Interp*) : Int32
  fun main_loop = Tk_MainLoop()
# EXTERN Tk_Window  Tk_MainWindow(Tcl_Interp *interp);
# EXTERN void   Tk_MoveWindow(Tk_Window tkwin, int x, int y);
# EXTERN Tcl_Interp * Tk_Interp(Tk_Window tkwin);

end

module Tcl
  class Interpreter
    getter :tcl_interp

    def initialize
      @tcl_interp = LibTcl.create_interp
    end

    def eval(command)
      LibTcl.eval(@tcl_interp, command.cstr)
    end
  end
end

# c = 0

module Tk
  class Label
    def initialize(master, name)
      # c = c + 1
      @name = ".l#{name}"
      @master = master
      interpreter.eval "label #{@name}"
    end

    def interpreter
      @master.interpreter
    end

    def text=(value)
      interpreter.eval "#{@name} configure -text \"#{value}\""
    end

    def pack
      interpreter.eval "pack #{@name}"
    end
  end

  class Window
    getter :interpreter
    getter :tk

    def initialize
      @interpreter = Tcl::Interpreter.new
      @tk = LibTk.init @interpreter.tcl_interp
    end

    def main_loop
      LibTk.main_loop
    end
  end
end
