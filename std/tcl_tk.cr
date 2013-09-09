lib LibTcl("tcl")
  struct Interp
  end

  struct AppInitProc
  end

  struct Obj
  end

  fun get_version = Tcl_GetVersion(major : Int32*, minor : Int32*, patch_level : Int32*, type : Void*)
  fun create_interp = Tcl_CreateInterp() : Interp*
  fun eval = Tcl_Eval(interp : Interp*, code : Char*) : Int32

  fun new_string_obj = Tcl_NewStringObj(bytes : Char*, length : Int32) : Obj*
  fun set_string_obj = Tcl_SetStringObj(objPtr : Obj*, bytes : Char*, length : Int32)
  fun get_string = Tcl_GetString(objPtr : Obj*) : Char*

  fun set_var = Tcl_SetVar(interp : Interp*, varName : Char*, newValue : Char*, flags : Int32) : Char*
  fun get_var = Tcl_GetVar(interp : Interp*, varName : Char*, flags : Int32) : Char*
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

    def set_var(name : String, value : String)
      LibTcl.set_var(@tcl_interp, name, value, 0)
    end

    def get_var(name : String)
      String.from_cstr(LibTcl.get_var(@tcl_interp, name, 0))
    end
  end

  class StringObj
    def initialize
      @obj = LibTcl.new_string_obj("", 0)
    end

    def value
      String.from_cstr(LibTcl.get_string(@obj))
    end

    def value=(val : String)
      LibTcl.set_string_obj(@obj, val, val.length)
    end
  end

  class StringVar
    @@string_vars = 0

    def initialize(interpreter)
      @@string_vars = @@string_vars + 1
      @name = "_string_var_#{@@string_vars}"
      @interpreter = interpreter
    end

    def value
      @interpreter.get_var(@name)
    end

    def value=(val)
      @interpreter.set_var(@name, val)
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
